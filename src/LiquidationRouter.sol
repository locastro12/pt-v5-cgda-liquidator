// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { LiquidationPair } from "./LiquidationPair.sol";
import { LiquidationPairFactory } from "./LiquidationPairFactory.sol";

error UndefinedLiquidationPairFactory();
error UnknownLiquidationPair(LiquidationPair liquidationPair);
error SwapExpired(uint256 deadline);

/// @title LiquidationRouter
/// @author G9 Software Inc.
/// @notice Serves as the user-facing swapping interface for Liquidation Pairs.
contract LiquidationRouter {
  using SafeERC20 for IERC20;

  /* ============ Events ============ */

  /// @notice Emitted when the router is created
  event LiquidationRouterCreated(LiquidationPairFactory indexed liquidationPairFactory);

  /// @notice Emitted after a swap occurs
  /// @param liquidationPair The pair that was swapped against
  /// @param receiver The address that received the output tokens
  /// @param amountOut The amount of output tokens received
  /// @param amountInMax The maximum amount of input tokens that could have been used
  /// @param amountIn The amount of input tokens that were actually used
  event SwappedExactAmountOut(
    LiquidationPair indexed liquidationPair,
    address indexed receiver,
    uint256 amountOut,
    uint256 amountInMax,
    uint256 amountIn,
    uint256 deadline
  );

  /* ============ Variables ============ */

  /// @notice The LiquidationPairFactory that this router uses.
  /// @dev LiquidationPairs will be checked to ensure they were created by the factory
  LiquidationPairFactory internal immutable _liquidationPairFactory;

  /// @notice Constructs a new LiquidationRouter
  /// @param liquidationPairFactory_ The factory that pairs will be verified to have been created by
  constructor(LiquidationPairFactory liquidationPairFactory_) {
    if(address(liquidationPairFactory_) == address(0)) {
      revert UndefinedLiquidationPairFactory();
    }
    _liquidationPairFactory = liquidationPairFactory_;

    emit LiquidationRouterCreated(liquidationPairFactory_);
  }

  /* ============ External Methods ============ */

  /// @notice Swaps the given amount of output tokens for at most input tokens
  /// @param _liquidationPair The pair to swap against
  /// @param _receiver The account to receive the output tokens
  /// @param _amountOut The exactly amount of output tokens expected
  /// @param _amountInMax The maximum of input tokens to spend
  /// @return The actual number of input tokens used
  function swapExactAmountOut(
    LiquidationPair _liquidationPair,
    address _receiver,
    uint256 _amountOut,
    uint256 _amountInMax,
    uint256 _deadline
  ) external onlyTrustedLiquidationPair(_liquidationPair) returns (uint256) {
    if (block.timestamp > _deadline) {
      revert SwapExpired(_deadline);
    }

    IERC20(_liquidationPair.tokenIn()).safeTransferFrom(
      msg.sender,
      _liquidationPair.target(),
      _liquidationPair.computeExactAmountIn(_amountOut)
    );

    uint256 amountIn = _liquidationPair.swapExactAmountOut(address(this), _amountOut, _amountInMax, "");

    IERC20(_liquidationPair.tokenOut()).safeTransfer(_receiver, _amountOut);

    emit SwappedExactAmountOut(_liquidationPair, _receiver, _amountOut, _amountInMax, amountIn, _deadline);

    return amountIn;
  }

  /// @notice Checks that the given pair was created by the factory
  /// @param _liquidationPair The pair to check
  modifier onlyTrustedLiquidationPair(LiquidationPair _liquidationPair) {
    if (!_liquidationPairFactory.deployedPairs(_liquidationPair)) {
      revert UnknownLiquidationPair(_liquidationPair);
    }
    _;
  }
}
