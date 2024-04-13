// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// make struct object universal
import {Product} from "./Product.sol";
import {GrindFI} from "./GrindFI.sol";


contract GrinfFIFactory is Product {
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

    function GFIStartTransaction(uint256 index, address seller) public {
        GrindFI grindFI = getGrandFIContract(index, seller);
        grindFI.startTransaction(msg.sender);
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