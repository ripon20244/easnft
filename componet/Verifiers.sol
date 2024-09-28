// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OrderStatus} from "./ConsiderationStructs.sol";

import {Assertions} from "./Assertions.sol";

import {SignatureVerification} from "./SignatureVerification.sol";

import {_revertInvalidTime, _revertOrderAlreadyFilled, _revertOrderIsCancelled, _revertOrderPartiallyFilled} from "./ConsiderationErrors.sol";

import {BulkOrderProof_keyShift, BulkOrderProof_keySize, BulkOrderProof_lengthAdjustmentBeforeMask, BulkOrderProof_lengthRangeAfterMask, BulkOrderProof_minSize, BulkOrderProof_rangeSize, ECDSA_MaxLength, OneWord, OneWordShift, ThirtyOneBytes, TwoWords} from "./ConsiderationConstants.sol";

/**
 * @title Verifiers
 * @author 0age
 * @notice Verifiers contains functions for performing verifications.
 */
contract Verifiers is Assertions, SignatureVerification {
    constructor() Assertions() {}
    /**
     * @dev Internal view function to ensure that the current time falls within
     *      an order's valid timespan.
     *
     * @param startTime       The time at which the order becomes active.
     * @param endTime         The time at which the order becomes inactive.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order is not active.
     *
     * @return valid A boolean indicating whether the order is active.
     */
    function _verifyTime(
        uint256 startTime,
        uint256 endTime,
        bool revertOnInvalid
    ) internal view returns (bool valid) {
        // Mark as valid if order has started and has not already ended.
        assembly {
            valid := and(
                iszero(gt(startTime, timestamp())),
                gt(endTime, timestamp())
            )
        }

        // Only revert on invalid if revertOnInvalid has been supplied as true.
        if (revertOnInvalid && !valid) {
            _revertInvalidTime(startTime, endTime);
        }
    }
    /**
     * @dev Internal view function to verify the signature of an order. An
     *      ERC-1271 fallback will be attempted if either the signature length
     *      is not 64 or 65 bytes or if the recovered signer does not match the
     *      supplied offerer. Note that in cases where a 64 or 65 byte signature
     *      is supplied, only standard ECDSA signatures that recover to a
     *      non-zero address are supported.
     *
     * @param offerer   The offerer for the order.
     * @param orderHash The order hash.
     * @param signature A signature from the offerer indicating that the order
     *                  has been approved.
     */

    function _verifySignature(
        address offerer,
        bytes32 orderHash,
        bytes memory signature
    ) internal view {
        // Determine whether the offerer is the caller.
        bool offererIsCaller;
        assembly {
            offererIsCaller := eq(offerer, caller())
        }

        // Skip signature verification if the offerer is the caller.
        if (offererIsCaller) {
            return;
        }

        // Derive the EIP-712 domain separator.
        bytes32 domainSeparator = _domainSeparator();

        // Derive original EIP-712 digest using domain separator and order hash.
        bytes32 originalDigest = _deriveEIP712Digest(
            domainSeparator,
            orderHash
        );

        // Read the length of the signature from memory and place on the stack.
        uint256 originalSignatureLength = signature.length;

        // Determine effective digest if signature has a valid bulk order size.
        bytes32 digest = originalDigest;

        // Ensure that the signature for the digest is valid for the offerer.
        _assertValidSignature(
            offerer,
            digest,
            originalDigest,
            originalSignatureLength,
            signature
        );
    }
    /**
     * @dev Internal view function to validate that a given order is fillable
     *      and not cancelled based on the order status.
     *
     * @param orderHash       The order hash.
     * @param orderStatus     The status of the order, including whether it has
     *                        been cancelled and the fraction filled.
     * @param onlyAllowUnused A boolean flag indicating whether partial fills
     *                        are supported by the calling function.
     * @param revertOnInvalid A boolean indicating whether to revert if the
     *                        order has been cancelled or filled beyond the
     *                        allowable amount.
     *
     * @return valid A boolean indicating whether the order is valid.
     */
    function _verifyOrderStatus(
        bytes32 orderHash,
        OrderStatus storage orderStatus,
        bool onlyAllowUnused,
        bool revertOnInvalid
    ) internal view returns (bool valid) {
        // Ensure that the order has not been cancelled.
        if (orderStatus.isCancelled) {
            // Only revert if revertOnInvalid has been supplied as true.
            if (revertOnInvalid) {
                _revertOrderIsCancelled(orderHash);
            }

            // Return false as the order status is invalid.
            return false;
        }

        // Read order status numerator from storage and place on stack.
        uint256 orderStatusNumerator = orderStatus.numerator;

        // If the order is not entirely unused...
        if (orderStatusNumerator != 0) {
            // ensure the order has not been partially filled when not allowed.
            if (onlyAllowUnused) {
                // Always revert on partial fills when onlyAllowUnused is true.
                _revertOrderPartiallyFilled(orderHash);
            }
            // Otherwise, ensure that order has not been entirely filled.
            else if (orderStatusNumerator >= orderStatus.denominator) {
                // Only revert if revertOnInvalid has been supplied as true.
                if (revertOnInvalid) {
                    _revertOrderAlreadyFilled(orderHash);
                }

                // Return false as the order status is invalid.
                return false;
            }
        }

        // Return true as the order status is valid.
        valid = true;
    }
}
