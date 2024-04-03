// SPDX-License-Identifier: MIT

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