// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice(
        AggregatorV3Interface priceFeedAddress
    ) internal view returns (uint256) {
        (, int256 answer, , , ) = priceFeedAddress.latestRoundData();
        // ETH/USD rate in 18 digit
        return uint256(answer * 10000000000);
    }

    function getConversionRate(
        uint256 ETHAmount,
        AggregatorV3Interface priceFeedAddress
    ) internal view returns (uint256) {
        uint256 ETHPrice = getPrice(priceFeedAddress);
        uint256 ETHAmountInUsd = (ETHPrice * ETHAmount) /
            1000000000000000000;

        return ETHAmountInUsd;
    }
}