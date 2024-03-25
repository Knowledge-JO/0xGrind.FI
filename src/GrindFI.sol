// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// make struct object universal
import {Product} from "./Product.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error GrindFI__OnlyBuyerAllowed();
error GrindFI__OnlySellerAllowed();
error GrindFI__SendRequiredPrice(uint256 price);
error GrindFI__StateError(string reason, GrindFI.State currentState);
error GrindFI__TransferError(string reason);

contract GrindFI is ReentrancyGuard {
    // Sellers can create, update and delete service ads.
    // Buyers can view this ads and the price attached to this ads
    // Buyers can create, update and delete job offers.
    // sellers can apply to this job offers
    // There can be different job offers which can be filtered based on sellers skills
    // buyers can chat with sellers (maybe for a negotiation or anything)
    // you'll have to process with their service ads to chat with them.
    // Only the buyer is able to start a transaction
    event StartTransaction(State currentState, address buyer, uint256 price); 
    event CancelTransaction(State currentState, address buyer);
    event DeliverProduct(State currentState, address buyer);
    event ProductAccepted(State currentState, address buyer);
    event RaiseDispute(State currentState, address buyer);

    mapping (address => Buyer) private buyerToBuyerInfo;

    enum State{AWAITING_BUYER_STARTS_TRANSACTION, AWAITING_DELIVERY, CANCELED, AWAITING_PAYMENT_RELEASE, TRANSACTION_COMPLETE}
    
    address private seller;

    Product.ProductDetail private productDetail;

    struct Buyer {
        address buyerAdress;
        uint256 pricePaid;
        uint256 availableForWithdrawal;
        uint256 startTime;
        State state;
    }

    constructor (string memory serviceName, uint256 price, uint256 duration) {
        seller = msg.sender;
        productDetail.service = serviceName;
        productDetail.price = price * 10**18;
        productDetail.duration = block.timestamp + (duration * 1 days);
    }

    modifier onlyBuyer(address supposedBuyer) {
        if(msg.sender != buyerToBuyerInfo[supposedBuyer].buyerAdress){
            revert GrindFI__OnlyBuyerAllowed();
        }
        _;
    }

    modifier onlySeller {
        if(msg.sender != seller){
            revert GrindFI__OnlySellerAllowed();
        }
        _;
    }

    // start transaction - by the buyer
    // freeze amount to be paid to seller

    // only buyer can call this function to start a transaction
    // the buyer sends the required amount to the contract
    // the duration for the delivery starts when this function is called
    function startTransaction () public payable {
        State state = getContractState(msg.sender);
        // make sure buyer can only send funds when the state is AWAITING_BUYER_STARTS_TRANSACTION
        if(msg.sender == seller){
            revert GrindFI__OnlyBuyerAllowed();
        }
        if( state != State.AWAITING_BUYER_STARTS_TRANSACTION) {
           revert GrindFI__StateError("You've started the transaction", state);
        }
        
        if(msg.value != productDetail.price){
            revert GrindFI__SendRequiredPrice(productDetail.price);
        }

        // clock has started ticking :)
        initializeBuyer(msg.sender, msg.value, block.timestamp, State.AWAITING_DELIVERY);
        buyerToBuyerInfo[msg.sender].availableForWithdrawal = msg.value;

        emit StartTransaction(getContractState(msg.sender), msg.sender, msg.value);
    }


    function initializeBuyer (address _buyer, uint256 _price, uint256 _startTime, State _state) private {
        buyerToBuyerInfo[_buyer].buyerAdress = _buyer;
        buyerToBuyerInfo[_buyer].pricePaid = _price;
        buyerToBuyerInfo[_buyer].startTime = _startTime; 
        buyerToBuyerInfo[_buyer].state = _state;
    }


    function updateState(address _buyer, State _state) private {
        buyerToBuyerInfo[_buyer].state = _state;
    }

    // only buyer can cancel the transaction.
    function cancelTransaction() external nonReentrant onlyBuyer(msg.sender) {
        State state = getContractState(msg.sender);
        if(state != State.AWAITING_DELIVERY) {
            revert GrindFI__StateError("Cannot call this function in this current state", state);
        }
        if(address(this).balance == 0) {
            revert GrindFI__TransferError("No funds to be withdrawn");
        }
        
        withdraw(msg.sender, msg.sender);
        updateState(msg.sender, State.CANCELED);

        emit CancelTransaction(getContractState(msg.sender), msg.sender);
    } 

    // This function updates the state of the contract to indicate product has been delivered
    function deliverProduct(address _buyer) public onlySeller {
        State state = getContractState(_buyer);
        if(state != State.AWAITING_DELIVERY) {
            revert GrindFI__StateError("Cannot call this function in this current state, Service has been marked as delivered", state);
        }
        updateState(_buyer, State.AWAITING_PAYMENT_RELEASE);
        emit DeliverProduct(getContractState(_buyer), _buyer);
    }

    // This function updates the state of the contract to indicate product has been received
    // this function will call a private function releasing the funds to the seller
    // This shows the buyer is ok with the delivered product
    function productAccepted() external nonReentrant onlyBuyer(msg.sender) {
        State state = getContractState(msg.sender);
        if(state != State.AWAITING_PAYMENT_RELEASE) {
            revert GrindFI__StateError("Cannot call this function in this current state", state);
        }

        withdraw(msg.sender, seller);
        updateState(msg.sender, State.TRANSACTION_COMPLETE);
        emit ProductAccepted(getContractState(msg.sender), msg.sender);
    }


    // A dispute can be raised if the buyer thinks the product delivered does not meet expectation
    // return state back t awaiting delivery to enable seller deliver updated product again
    function raiseDispute() public onlyBuyer(msg.sender) {
        State state = getContractState(msg.sender);
        if(state != State.AWAITING_PAYMENT_RELEASE) {
            revert GrindFI__StateError("Cannot call this function in this current state", state); 
        }
        updateState(msg.sender, State.AWAITING_DELIVERY);
        emit RaiseDispute(getContractState(msg.sender), msg.sender);
    }


    function withdraw(address _buyer, address receiver) private {
        State state = getContractState(_buyer);
        uint256 pricePaid =  buyerToBuyerInfo[_buyer].pricePaid;
        if(state != State.AWAITING_PAYMENT_RELEASE) {
            revert GrindFI__StateError("Cannot call this function in this current state", state);
        }
        (bool success, ) = (receiver).call{value: pricePaid}("");
        if( !success) revert GrindFI__TransferError("Transfer failed");
        buyerToBuyerInfo[_buyer].availableForWithdrawal -= pricePaid;
    }


    // view functions
    function getContractState(address _buyerAddress) public view returns (State) {
        return buyerToBuyerInfo[_buyerAddress].state;
    }

    function getStateTime(address _buyerAddress) public view returns (uint256) {
       return buyerToBuyerInfo[_buyerAddress].startTime;
    }

    function getBuyerInfo(address _buyerAddress) public view returns (Buyer memory) {
        return buyerToBuyerInfo[_buyerAddress];
    }

    function getSeller() public view returns (address) {
        return seller;
    }

    function getProductDetails() public view returns (Product.ProductDetail memory) {
        return productDetail;
    }
}
