//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract Escrow {
    address buyer;
    address moderator;
    address[] moderatorList;
    address public seller;
    uint public startTime;
    uint endTime;
    bool product_delivered;
    bool buyerOK;

    enum State{Awaiting_buyer_payement, Awaiting_delivery, Awaiting_fund_release, Transaction_Complete, Dispute}
    State public current_state;

    constructor(address _seller) {
        buyer = msg.sender;
        seller = _seller;
        current_state = State.Awaiting_buyer_payement;
    }

    struct Details {
        string product;
        uint256 cost;
        string date;
    }

    Details public productDetails;
    
    function proceed(string memory _product, uint256 _cost, string memory _date) public {
        require(current_state == State.Awaiting_buyer_payement, "Initiated already");
        require(msg.sender == seller, "You are not the seller!");
        productDetails.product = _product;
        productDetails.cost = _cost * 1000000000000000000;
        productDetails.date = _date;
        startTime = block.number;
    }

    function startTransaction() public payable{
        require(current_state == State.Awaiting_buyer_payement, "Initiated Already");
        require(msg.sender == buyer, "You are not the buyer!!");
        require(msg.value >= productDetails.cost);
        current_state = State.Awaiting_delivery;
    }

    function deliver_product() public {
        require(current_state == State.Awaiting_delivery, "Initiated Already");
        require(msg.sender == seller, "You are not the seller!");
        product_delivered = true;
        current_state = State.Awaiting_fund_release;
    }

    function product_received() public {
        require(current_state == State.Awaiting_fund_release, "Initiated Already");
        require(msg.sender == buyer, "You are not the buyer!");
        buyerOK = true;
        if (product_delivered == true){
            release_payment();
        }
    }

    function release_payment() private {
        payable(seller).transfer((address(this).balance));
        current_state = State.Transaction_Complete;
    }

    function there_is_a_dispute() public {
        current_state = State.Dispute;
    }

    function _balance() public view returns(uint256){
       return address(this).balance;
    }

    function withdraw() public {
        require(msg.sender == buyer, "You are not the buyer");
        require(current_state == State.Awaiting_delivery);
        if (product_delivered == true && buyerOK == false){
            (bool os, ) = payable(buyer).call{value: address(this).balance}("");
            require(os);
        }
        
    }

    function  withdraw_moderator(address _buyerOrSeller) public {
        require(current_state == State.Dispute, "There is no dispute");
        (bool os, ) = payable(_buyerOrSeller).call{value: address(this).balance}("");
        require(os);
    }
}