//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import  "./Escrow.sol";

contract EscrowFactory{
    //map buyer to the contract created
    // moderators cannot create contracts
    
    address[] public buyersList;
    address public seller_wallet;
    Escrow[] public escrowArray;

    mapping (address => BuyerAndContract) public buyerToEscrowContract;

    mapping( Escrow => uint256 ) public escrowArrayIndexes;

    constructor (address _seller){
        seller_wallet = _seller;
    }

    struct BuyerAndContract{
        address buyer;
        Escrow[] escrow;
    }

    function createEscrowContract() public {
        Escrow escrow = new Escrow(seller_wallet);
        escrowArray.push(escrow);
        buyerToEscrowContract[msg.sender].buyer = msg.sender;
        buyerToEscrowContract[msg.sender].escrow.push(escrow);
        escrowArrayIndexes[escrow] = escrowArray.length-1;
        //test.push(Test(msg.sender, escrow));
        buyersList.push(msg.sender);
    }

    function escrowLength() public view returns(uint256) {
        return escrowArray.length;
    }

    function getEscrowContracts()public view returns(Escrow[] memory){
        return buyerToEscrowContract[msg.sender].escrow;
    }

    function efProceed(uint256 _escrowArrayIndex, string memory _escrowProduct, uint256 _escrowCost, string memory _escrowDate) public{
        Escrow escrow = Escrow(address(buyerToEscrowContract[msg.sender].escrow[_escrowArrayIndex]));
        escrow.proceed(_escrowProduct, _escrowCost, _escrowDate);
    }
}