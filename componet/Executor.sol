// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ItemType} from "./ConsiderationEnums.sol";

import {ReceivedItem} from "./ConsiderationStructs.sol";

import {Verifiers} from "./Verifiers.sol";

import {TokenTransferrer} from "./TokenTransferrer.sol";

import {Accumulator_array_length_ptr, Accumulator_array_offset_ptr, Accumulator_array_offset, Accumulator_conduitKey_ptr, Accumulator_itemSizeOffsetDifference, Accumulator_selector_ptr, AccumulatorArmed, AccumulatorDisarmed, FreeMemoryPointerSlot, OneWord, TwoWords} from "./ConsiderationConstants.sol";

import {Error_selector_offset, NativeTokenTransferGenericFailure_error_account_ptr, NativeTokenTransferGenericFailure_error_amount_ptr, NativeTokenTransferGenericFailure_error_length, NativeTokenTransferGenericFailure_error_selector} from "./ConsiderationErrorConstants.sol";

import {_revertInvalidERC721TransferAmount, _revertUnusedItemParameters} from "./ConsiderationErrors.sol";

/**
 * @title Executor
 * @author 0age
 * @notice Executor contains functions related to processing executions (i.e.
 *         transferring items, either directly or via conduits).
 */
contract Executor is Verifiers, TokenTransferrer {
    constructor() Verifiers() {}

    /**
     * @dev Internal function to transfer a given item, either directly or via
     *      a corresponding conduit.
     *
     * @param item        The item to transfer, including an amount and a
     *                    recipient.
     * @param from        The account supplying the item.
     *
     * @param conduitKey
     *
     * @param accumulator
     */
    function _transfer(
        ReceivedItem memory item,
        address from,
        bytes32 conduitKey,
        bytes memory accumulator
    ) internal {
        // If the item type indicates Ether or a native token...
        if (item.itemType == ItemType.NATIVE) {
            // Ensure neither the token nor the identifier parameters are set.
            if ((uint160(item.token) | item.identifier) != 0) {
                _revertUnusedItemParameters();
            }

            // transfer the native tokens to the recipient.
            _transferNativeTokens(item.recipient, item.amount);
        } else if (item.itemType == ItemType.ERC20) {
            // Ensure that no identifier is supplied.
            if (item.identifier != 0) {
                _revertUnusedItemParameters();
            }

            // Transfer ERC20 tokens from the source to the recipient.
            _transferERC20(
                item.token,
                from,
                item.recipient,
                item.amount,
                conduitKey,
                accumulator
            );
        }
        {
            // Transfer ERC721 token from the source to the recipient.
            _transferERC721(
                item.token,
                from,
                item.recipient,
                item.identifier,
                item.amount,
                conduitKey,
                accumulator
            );
        }
    }

    /**
     * @dev Internal function to transfer Ether or other native tokens to a
     *      given recipient.
     *
     * @param to     The recipient of the transfer.
     * @param amount The amount to transfer.
     */
    function _transferNativeTokens(
        address payable to,
        uint256 amount
    ) internal {
        // Ensure that the supplied amount is non-zero.
        _assertNonZeroAmount(amount);

        // Declare a variable indicating whether the call was successful or not.
        bool success;

        assembly {
            // Transfer the native token and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        // If the call fails...
        if (!success) {
            // Revert and pass the revert reason along if one was returned.
            _revertWithReasonIfOneIsReturned();

            // Otherwise, revert with a generic error message.
            assembly {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, NativeTokenTransferGenericFailure_error_selector)

                // Write `to` and `amount` arguments.
                mstore(NativeTokenTransferGenericFailure_error_account_ptr, to)
                mstore(
                    NativeTokenTransferGenericFailure_error_amount_ptr,
                    amount
                )

                // revert(abi.encodeWithSignature(
                //     "NativeTokenTransferGenericFailure(address,uint256)",
                //     to,
                //     amount
                // ))
                revert(
                    Error_selector_offset,
                    NativeTokenTransferGenericFailure_error_length
                )
            }
        }
    }
    /**
     * @dev Internal function to transfer ERC20 tokens from a given originator
     *      to a given recipient using a given conduit if applicable. Sufficient
     *      approvals must be set on this contract or on a respective conduit.
     *
     * @param token       The ERC20 token to transfer.
     * @param from        The originator of the transfer.
     * @param to          The recipient of the transfer.
     * @param amount      The amount to transfer.
     * @param conduitKey
     * @param accumulator
     */

    function _transferERC20(
        address token,
        address from,
        address to,
        uint256 amount,
        bytes32 conduitKey,
        bytes memory accumulator
    ) internal {
        // Ensure that the supplied amount is non-zero.
        _assertNonZeroAmount(amount);

        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Perform the token transfer directly.
            _performERC20Transfer(token, from, to, amount);
        }
    }
    /**
     * @dev Internal function to transfer a single ERC721 token from a given
     *      originator to a given recipient. Sufficient approvals must be set,
     *      either on the respective conduit or on this contract itself.
     *
     * @param token       The ERC721 token to transfer.
     * @param from        The originator of the transfer.
     * @param to          The recipient of the transfer.
     * @param identifier  The tokenId to transfer.
     * @param amount      The amount to transfer (must be 1 for ERC721)
     * @param conduitKey
     * @param accumulator
     */

    function _transferERC721(
        address token,
        address from,
        address to,
        uint256 identifier,
        uint256 amount,
        bytes32 conduitKey,
        bytes memory accumulator
    ) internal {
        // If no conduit has been specified...
        if (conduitKey == bytes32(0)) {
            // Ensure that exactly one 721 item is being transferred.
            if (amount != 1) {
                _revertInvalidERC721TransferAmount(amount);
            }

            // Perform transfer via the token contract directly.
            _performERC721Transfer(token, from, to, identifier);
        }
    }
}
