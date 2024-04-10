// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    // returns the current price of ETH in USD
    function getETHPrice(
        AggregatorV3Interface priceFeedAddress
    ) internal view returns (uint256 ETHPriceInUSD) {
        (, int256 answer, , , ) = priceFeedAddress.latestRoundData();
        // ETH/USD rate in 18 digit
        ETHPriceInUSD = uint256(answer * 10000000000);
        return ETHPriceInUSD;
    }


    // converts any amount of ETH passed to it to its equivalent in USD
    function getETHConversionRate(
        uint256 ETHAmount,
        AggregatorV3Interface priceFeedAddress
    ) internal view returns (uint256) {
        uint256 ETHPrice = getETHPrice(priceFeedAddress);
        uint256 ETHAmountInUsd = (ETHPrice * ETHAmount) /
            1000000000000000000;

        return ETHAmountInUsd;
    }
}