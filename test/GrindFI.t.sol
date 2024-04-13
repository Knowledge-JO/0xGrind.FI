// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {GrindFIBase, GrindFI__OnlyBuyerAllowed,GrindFI__SendRequiredPrice} from "../src/GrindFIBase.sol";
import {Product} from "../src/Product.sol";
import "../lib/forge-std/src/console.sol";
contract GrindFITest is Test, Product {
    GrindFIBase grindFI;

    string private service = "Smart Contract Developer";
    uint256 price = 0.3 ether;
    uint256 duration = 10;
    uint256 correctDuration;

    receive() external payable {}

    function setUp() external {
        correctDuration = (duration * 1 days) + block.timestamp;
        grindFI = new GrindFIBase(service, price, duration);
    }

    function test_specifiedServiceInConstructor() external view {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        assertEq(service, productDetails.service);
        
    }

    function test_specifiedPriceInConstructor() external view {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        assertEq(price, productDetails.price);
    }

    function test_specifiedDurationInConstructor() external view {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        assertEq(correctDuration, productDetails.duration);
    }

    // selller must not be able to start transaction
    function test_startTransaction_revertWhen_callerIsNotBuyer() external {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        uint256 productPrice = productDetails.price;
        vm.expectRevert(GrindFI__OnlyBuyerAllowed.selector);
        grindFI.startTransaction{value: productPrice}();
        
    }

    // only buyer can start transaction
    function test_startTransaction() external {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        uint256 productPrice = productDetails.price;
        // create a new BuyerC object
        BuyerC buyerC = new BuyerC();
        // transfer funds to BuyerC contract representing the buyer
        payable(buyerC).transfer(productPrice + 200000);
        // changing the caller address to BuyerC
        vm.prank(address(buyerC));
        grindFI.startTransaction{value: productPrice}();
        Buyer memory buyerInfo = grindFI.getBuyerInfo(address(buyerC));
        assertEq(productPrice, buyerInfo.pricePaid);
    }

    function test_revertWhen_buyerDoesNotPayRequiredPrice() external {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        uint256 productPrice = productDetails.price;
        // create a new BuyerC object
        BuyerC buyerC = new BuyerC();
        // transfer funds to BuyerC contract representing the buyer
        payable(buyerC).transfer(productPrice + 200000);
        // changing the caller address to BuyerC
        vm.prank(address(buyerC));
        bytes4 selector = bytes4(keccak256("GrindFI__SendRequiredPrice(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, productPrice));
        grindFI.startTransaction{value: 200000 }();
    }

    function test_cancelTransaction() external {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        uint256 productPrice = productDetails.price;
        // create a new BuyerC object
        BuyerC buyerC = new BuyerC();
        // transfer funds to BuyerC contract representing the buyer
        payable(buyerC).transfer(productPrice + 200000);
        // changing the caller address to BuyerC
        vm.startPrank(address(buyerC));
        grindFI.startTransaction{value: productPrice}();
        grindFI.cancelTransaction();
        vm.stopPrank();
        Buyer memory buyerInfo = grindFI.getBuyerInfo(address(buyerC));
        assertEq(buyerInfo.productDelivered, false);
    }

    function test_deliverProduct() external {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        uint256 productPrice = productDetails.price;
        // create a new BuyerC object
        BuyerC buyerC = new BuyerC();
        // transfer funds to BuyerC contract representing the buyer
        payable(buyerC).transfer(productPrice + 200000);
        // changing the caller address to BuyerC
        vm.prank(address(buyerC));
        // buyer starts transaction
        grindFI.startTransaction{value: productPrice}();
        // seller delivers product
        grindFI.deliverProduct(address(buyerC));
        Buyer memory buyerInfo = grindFI.getBuyerInfo(address(buyerC));
        assertEq(buyerInfo.productDelivered, true);
    }

    // productAccepted
    function test_productAccepted() external {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        uint256 productPrice = productDetails.price;
        // create a new BuyerC object
        BuyerC buyerC = new BuyerC();
        // transfer funds to BuyerC contract representing the buyer
        payable(buyerC).transfer(productPrice + 200000);

        // buyer starts transaction
        vm.prank(address(buyerC));
        grindFI.startTransaction{value: productPrice}(); 

        // seller delivers product
        grindFI.deliverProduct(address(buyerC));

        // buyer accepts product
        vm.prank(address(buyerC));
        grindFI.productAccepted();
        
        Buyer memory buyerInfo = grindFI.getBuyerInfo(address(buyerC));
        assertFalse(buyerInfo.availableForWithdrawal > productPrice);
    }

    // raiseDispute
    function test_raiseDispute() external {
        ProductDetail memory productDetails = grindFI.getProductDetails();
        uint256 productPrice = productDetails.price;
        // create a new BuyerC object
        BuyerC buyerC = new BuyerC();
        // transfer funds to BuyerC contract representing the buyer
        payable(buyerC).transfer(productPrice + 200000);

        // buyer starts transaction
        vm.prank(address(buyerC));
        grindFI.startTransaction{value: productPrice}(); 

        // seller delivers product
        grindFI.deliverProduct(address(buyerC));

        // buyer accepts product
        vm.prank(address(buyerC));
        grindFI.raiseDispute();
        
        Buyer memory buyerInfo = grindFI.getBuyerInfo(address(buyerC));
        assertEq(buyerInfo.productDelivered, false);
    }

}


contract BuyerC {
    // enable this contract receive ether
    receive() external payable {}
}