// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @title An interface for a contract that is capable of deploying USUM markets
/// @notice A contract that constructs a market must implement this to pass arguments to the market
/// @dev This is used to avoid having constructor arguments in the market contract, which results in the init code hash
/// of the market being constant allowing the CREATE2 address of the market to be cheaply computed on-chain
interface IMarketDeployer {
    /// @notice Get the parameters to be used in constructing the market, set transiently during market creation.
    /// @dev Called by the market constructor to fetch the parameters of the market
    /// Returns underlyingAsset The underlying asset of the market
    /// Returns settlementToken The settlement token of the market
    /// Returns vPoolCapacity Capacity of virtual future pool
    /// Returns vPoolA Amplification coefficient of virtual future pool, precise value
    function parameters()
        external
        view
        returns (
            address oracleProvider,
            address settlementToken,
            string memory lpTokenUri
        );
}
