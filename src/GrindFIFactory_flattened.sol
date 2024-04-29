
// File: lib/openzeppelin-contracts/contracts//utils/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// File: src/Product.sol



pragma solidity ^0.8.13;


contract Product {
    
    enum State{AWAITING_BUYER_STARTS_TRANSACTION, AWAITING_DELIVERY, CANCELED, AWAITING_PAYMENT_RELEASE, DISPUTE_RAISED, TRANSACTION_COMPLETE}
    
    struct ProductDetail {
        string service;
        uint256 price;
        uint256 duration;
    }

    struct Buyer {
        address buyerAdress;
        uint256 pricePaid;
        uint256 availableForWithdrawal;
        uint256 startTime;
        State state;
        bool productDelivered;
    }

}
// File: src/GrindFI.sol


pragma solidity ^0.8.13;

// make struct object universal



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

// File: src/GrindFIFactory.sol


pragma solidity ^0.8.13;

// make struct object universal




contract GrindFIFactory is Product {
    // create new GrindFI contracts
    
    mapping (address => GrindFI[]) private sellerToContractCreated;

    address private owner;

    constructor () {
        owner= msg.sender;
    }

    function createSellerAd(string memory serviceName, uint256 price, uint256 duration) public {
        GrindFI grindFI = new GrindFI(serviceName, price, duration, msg.sender, address(this));
        sellerToContractCreated[msg.sender].push(grindFI);
    }

    function GFIStartTransaction(uint256 index, address seller) public payable {
        GrindFI grindFI = getGrandFIContract(index, seller);
        grindFI.startTransaction{value: msg.value}(msg.sender);
    }

    // only buyer
    function GFICancelTransaction(uint256 index, address seller) public {
        GrindFI grindFI = getGrandFIContract(index, seller);
        grindFI.cancelTransaction(msg.sender);
    }

    // only seller
    function GFIDeliverProduct(uint256 index, address buyer) public {
        GrindFI grindFI = getGrandFIContract(index, msg.sender);
        grindFI.deliverProduct(msg.sender, buyer);
    }

    // only buyer
    function GFIProductAccepted(uint256 index, address seller) public {
        GrindFI grindFI = getGrandFIContract(index, seller);
        grindFI.productAccepted(msg.sender);
    }


    // only buyer
    function GFIRaiseDispute(uint256 index, address seller) public {
        GrindFI grindFI = getGrandFIContract(index, seller);
        grindFI.raiseDispute(msg.sender);
    }
    

    function getGrandFIContract(uint256 index, address seller) public view returns(GrindFI) {
        return sellerToContractCreated[seller][index];
    }

    function getAllAds(address _sellerAddress) public view returns(GrindFI[] memory) {
        return sellerToContractCreated[_sellerAddress];
    }

    function GFIGetContractState(uint256 index, address seller, address _buyerAddress) public view returns(State) {
        GrindFI grindFI = getGrandFIContract(index, seller);
        return grindFI.getContractState(_buyerAddress);
    }

    function GFIGetStartTime(uint256 index, address seller, address _buyerAddress) public view returns(uint256) {
        GrindFI grindFI = getGrandFIContract(index, seller);
        return grindFI.getStartTime(_buyerAddress);
    }

    function GFIGetBuyerInfo(uint256 index, address seller, address _buyerAddress) public view returns(Buyer memory) {
        GrindFI grindFI = getGrandFIContract(index, seller);
        return grindFI.getBuyerInfo(_buyerAddress);
    }

    function GFIGetSeller(uint256 index, address seller) public view returns(address) {
        GrindFI grindFI = getGrandFIContract(index, seller);
        return grindFI.getSeller();
    }

    function GFIGetProductDetails(uint256 index, address seller) public view returns(ProductDetail memory){
        GrindFI grindFI = getGrandFIContract(index, seller);
        return grindFI.getProductDetails();
    }
}