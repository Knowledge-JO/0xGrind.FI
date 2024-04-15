// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {GrindFIFactory} from "../src/GrindFIFactory.sol";
import {GrindFI} from "../src/GrindFI.sol";

contract GrindFIFactoryTest is Test {

    GrindFIFactory grindFIFactory;

    function setUp() external {
        grindFIFactory = new GrindFIFactory();
        grindFIFactory.createSellerAd("Smart contract developer", 1 ether, 30);
    }


    function test_GFIStartTransaction() external {
        BuyerC buyerC = new BuyerC ();
        payable(buyerC).transfer(1*10**18 + 100000);

        // start transaction with a different address
        vm.prank(address(buyerC));
        grindFIFactory.GFIStartTransaction{value: 1*10**18}(0, address(this));
        assertFalse(address(this).balance <= 0);
    }

    function test_revertWhen_GFI_buyerDoesNotPayRequiredPrice() external {
        BuyerC buyerC = new BuyerC ();
        payable(buyerC).transfer(1*10**18 + 100000);

        // start transaction with a different address
        // required price is 1 ether =  1*10**18
        vm.prank(address(buyerC));
        bytes4 selector = bytes4(keccak256("GrindFI__SendRequiredPrice(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 1*10**18));
        grindFIFactory.GFIStartTransaction{value: 1*10**10}(0, address(this));
    }


    function test_GFICancelTransaction() external {
        BuyerC buyerC = new BuyerC ();
        payable(buyerC).transfer(1*10**18 + 100000);
        vm.startPrank(address(buyerC));
        grindFIFactory.GFIStartTransaction{value: 1*10**18}(0, address(this));
        grindFIFactory.GFICancelTransaction(0, address(this));
        vm.stopPrank();
    }

}


contract BuyerC {
    receive () external payable {}
}