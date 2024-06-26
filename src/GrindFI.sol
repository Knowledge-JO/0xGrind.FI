// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// make struct object universal
import {Product} from "./Product.sol";
import "openzeppelin/contracts/utils/ReentrancyGuard.sol";

error GrindFI__OnlyBuyerAllowed();
error GrindFI__OnlySellerAllowed();
error GrindFI__SendRequiredPrice(uint256 price);
error GrindFI__StateError(string reason, Product.State currentState);
error GrindFI__TransferError(string reason);
error GrindFI__OnlyFactoryAllowed();

contract GrindFI is ReentrancyGuard, Product {
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
    
    address private seller;

    ProductDetail private productDetail;
    address private GFIFactoryAddress;

    constructor (string memory serviceName, uint256 price, uint256 duration, address _seller, address _GFIFactoryAddress) {
        seller = _seller;
        productDetail.service = serviceName;
        productDetail.price = price;
        productDetail.duration = block.timestamp  + (duration * 1 days);
        GFIFactoryAddress = _GFIFactoryAddress;

    }

    modifier onlyBuyer(address supposedBuyer) {
        if(supposedBuyer != buyerToBuyerInfo[supposedBuyer].buyerAdress){
            revert GrindFI__OnlyBuyerAllowed();
        }
        _;
    }

    modifier onlySeller(address supposedSeller) {
        if(supposedSeller != seller){
            revert GrindFI__OnlySellerAllowed();
        }
        _;
    }


    modifier onlyFactory {
        if(msg.sender != GFIFactoryAddress) {
            revert GrindFI__OnlyFactoryAllowed();
        }
        _;
    }

    // start transaction - by the buyer
    // freeze amount to be paid to seller

    // only buyer can call this function to start a transaction
    // the buyer sends the required amount to the contract
    // the duration for the delivery starts when this function is called
    function startTransaction (address _buyer) onlyFactory public payable {
        State state = getContractState(_buyer);
        // make sure buyer can only send funds when the state is AWAITING_BUYER_STARTS_TRANSACTION
        if(_buyer == seller){
            revert GrindFI__OnlyBuyerAllowed();
        }
        if( state != State.AWAITING_BUYER_STARTS_TRANSACTION) {
           revert GrindFI__StateError("You've started the transaction", state);
        }
        
        if(msg.value < productDetail.price){
            revert GrindFI__SendRequiredPrice(productDetail.price);
        }

        // clock has started ticking :)
        initializeBuyer(_buyer, msg.value, block.timestamp, State.AWAITING_DELIVERY);
        buyerToBuyerInfo[_buyer].availableForWithdrawal = msg.value;

        emit StartTransaction(getContractState(_buyer),_buyer, msg.value);
    }


    function initializeBuyer (address _buyer, uint256 _price, uint256 _startTime, State _state) internal {
        buyerToBuyerInfo[_buyer].buyerAdress = _buyer;
        buyerToBuyerInfo[_buyer].pricePaid = _price;
        buyerToBuyerInfo[_buyer].startTime = _startTime; 
        buyerToBuyerInfo[_buyer].state = _state;
    }


    function updateState(address _buyer, State _state) internal {
        buyerToBuyerInfo[_buyer].state = _state;
    }

    // only buyer can cancel the transaction.
    function cancelTransaction(address _buyer) external onlyFactory nonReentrant onlyBuyer(_buyer) {
        State state = getContractState(_buyer);
        uint256 pricePaid =  buyerToBuyerInfo[_buyer].pricePaid;
        if(state != State.AWAITING_DELIVERY) {
            revert GrindFI__StateError("Cannot call this cancelTransaction() in this current state", state);
        }
        if(address(this).balance == 0) {
            revert GrindFI__TransferError("No funds to be withdrawn");
        }
        
        (bool success, ) = (_buyer).call{value: pricePaid}("");
        if( !success) revert GrindFI__TransferError("Transfer failed");
        updateState(_buyer, State.CANCELED);

        emit CancelTransaction(getContractState(_buyer), _buyer);
    } 

    // This function updates the state of the contract to indicate product has been delivered
    function deliverProduct(address _seller, address _buyer) public onlyFactory onlySeller(_seller) {
        State state = getContractState(_buyer);
        if(state != State.AWAITING_DELIVERY) {
            revert GrindFI__StateError("Cannot call this function in this current state, Service has been marked as delivered", state);
        }
        updateState(_buyer, State.AWAITING_PAYMENT_RELEASE);
        buyerToBuyerInfo[_buyer].productDelivered = true;
        emit DeliverProduct(getContractState(_buyer), _buyer);
    }

    // This function updates the state of the contract to indicate product has been received
    // this function will call a private function releasing the funds to the seller
    // This shows the buyer is ok with the delivered product
    function productAccepted(address _buyer) external onlyFactory nonReentrant onlyBuyer(_buyer) {
        State state = getContractState(_buyer);
        if(state != State.AWAITING_PAYMENT_RELEASE) {
            revert GrindFI__StateError("Cannot call this function in this current state", state);
        }

        withdraw(_buyer, seller);
        updateState(_buyer, State.TRANSACTION_COMPLETE);
        emit ProductAccepted(getContractState(_buyer), _buyer);
    }


    // A dispute can be raised if the buyer thinks the product delivered does not meet expectation
    // return state back t awaiting delivery to enable seller deliver updated product again
    function raiseDispute(address _buyer) public onlyFactory onlyBuyer(_buyer) {
        State state = getContractState(_buyer);
        if(state != State.AWAITING_PAYMENT_RELEASE) {
            revert GrindFI__StateError("Cannot call this function in this current state", state); 
        }
        updateState(_buyer, State.DISPUTE_RAISED);
        buyerToBuyerInfo[_buyer].productDelivered = false;
        emit RaiseDispute(getContractState(_buyer), _buyer);
    }


    function withdraw(address _buyer, address receiver) internal {
        State state = getContractState(_buyer);
        uint256 pricePaid =  buyerToBuyerInfo[_buyer].pricePaid;
        if(state != State.AWAITING_PAYMENT_RELEASE) {
            revert GrindFI__StateError("Cannot call withdraw() in this current state", state);
        }
        (bool success, ) = (receiver).call{value: pricePaid}("");
        if( !success) revert GrindFI__TransferError("Transfer failed");
        buyerToBuyerInfo[_buyer].availableForWithdrawal -= pricePaid;
    }


    // view functions
    function getContractState(address _buyerAddress) public view returns (State) {
        return buyerToBuyerInfo[_buyerAddress].state;
    }

    function getStartTime(address _buyerAddress) public view returns (uint256) {
       return buyerToBuyerInfo[_buyerAddress].startTime;
    }

    function getBuyerInfo(address _buyerAddress) public view returns (Buyer memory) {
        return buyerToBuyerInfo[_buyerAddress];
    }

    function getSeller() public view returns (address) {
        return seller;
    }

    function getProductDetails() public view returns (ProductDetail memory) {
        return productDetail;
    }
}
