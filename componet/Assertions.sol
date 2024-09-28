// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {OrderParameters} from "./ConsiderationStructs.sol";

import {GettersAndDerivers} from "./GettersAndDerivers.sol";

import {TokenTransferrerErrors} from "../interfaces/TokenTransferrerErrors.sol";

import {CounterManager} from "./CounterManager.sol";

import {AdditionalRecipient_size_shift, AddressDirtyUpperBitThreshold, BasicOrder_additionalRecipients_head_cdPtr, BasicOrder_additionalRecipients_head_ptr, BasicOrder_additionalRecipients_length_cdPtr, BasicOrder_basicOrderType_cdPtr, BasicOrder_basicOrderType_range, BasicOrder_considerationToken_cdPtr, BasicOrder_offerer_cdPtr, BasicOrder_offerToken_cdPtr, BasicOrder_parameters_cdPtr, BasicOrder_parameters_ptr, BasicOrder_signature_cdPtr, BasicOrder_signature_ptr, BasicOrder_zone_cdPtr} from "./ConsiderationConstants.sol";

import {Error_selector_offset, MissingItemAmount_error_length, MissingItemAmount_error_selector} from "./ConsiderationErrorConstants.sol";

import {_revertInvalidBasicOrderParameterEncoding, _revertMissingOriginalConsiderationItems} from "./ConsiderationErrors.sol";

contract Assertions is
    GettersAndDerivers,
    CounterManager,
    TokenTransferrerErrors
{
    constructor() GettersAndDerivers() {}

    function _assertConsiderationLengthAndGetOrderHash(
        OrderParameters memory orderParameters
    ) internal view returns (bytes32) {
        // Ensure supplied consideration array length is not less than original.
        _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
            orderParameters.consideration.length,
            orderParameters.totalOriginalConsiderationItems
        );

        // Derive and return order hash using current counter for the offerer.
        return
            _deriveOrderHash(
                orderParameters,
                _getCounter(orderParameters.offerer)
            );
    }

    function _assertConsiderationLengthIsNotLessThanOriginalConsiderationLength(
        uint256 suppliedConsiderationItemTotal,
        uint256 originalConsiderationItemTotal
    ) internal pure {
        // Ensure supplied consideration array length is not less than original.
        if (suppliedConsiderationItemTotal < originalConsiderationItemTotal) {
            _revertMissingOriginalConsiderationItems();
        }
    }

    function _assertNonZeroAmount(uint256 amount) internal pure {
        assembly {
            if iszero(amount) {
                // Store left-padded selector with push4, mem[28:32] = selector
                mstore(0, MissingItemAmount_error_selector)

                // revert(abi.encodeWithSignature("MissingItemAmount()"))
                revert(Error_selector_offset, MissingItemAmount_error_length)
            }
        }
    }

    function _assertValidBasicOrderParameters() internal pure {
        // Declare a boolean designating basic order parameter offset validity.
        bool validOffsets;

        // Utilize assembly in order to read offset data directly from calldata.
        assembly {
            /*
             * Checks:
             * 1. Order parameters struct offset == 0x20
             * 2. Additional recipients arr offset == 0x240
             * 3. Signature offset == 0x260 + (recipients.length * 0x40)
             * 4. BasicOrderType between 0 and 23 (i.e. < 24)
             * 5. Offerer, zone, offer token, and consideration token have no
             *    upper dirty bits — each argument is type(uint160).max or less
             */
            validOffsets := and(
                and(
                    and(
                        // Order parameters at cd 0x04 must have offset of 0x20.
                        eq(
                            calldataload(BasicOrder_parameters_cdPtr),
                            BasicOrder_parameters_ptr
                        ),
                        // Additional recipients (cd 0x224) arr offset == 0x240.
                        eq(
                            calldataload(
                                BasicOrder_additionalRecipients_head_cdPtr
                            ),
                            BasicOrder_additionalRecipients_head_ptr
                        )
                    ),
                    // Signature offset == 0x260 + (recipients.length * 0x40).
                    eq(
                        // Load signature offset from calldata 0x244.
                        calldataload(BasicOrder_signature_cdPtr),
                        // Expected offset is start of recipients + len * 64.
                        add(
                            BasicOrder_signature_ptr,
                            shl(
                                // Each additional recipient has length of 0x40.
                                AdditionalRecipient_size_shift,
                                // Additional recipients length at cd 0x264.
                                calldataload(
                                    BasicOrder_additionalRecipients_length_cdPtr
                                )
                            )
                        )
                    )
                ),
                and(
                    // Ensure BasicOrderType parameter is less than 0x18.
                    lt(
                        // BasicOrderType parameter at calldata offset 0x124.
                        calldataload(BasicOrder_basicOrderType_cdPtr),
                        // Value should be less than 24.
                        BasicOrder_basicOrderType_range
                    ),
                    // Ensure no dirty upper bits are present on offerer, zone,
                    // offer token, or consideration token.
                    lt(
                        or(
                            or(
                                // Offerer parameter at calldata offset 0x84.
                                calldataload(BasicOrder_offerer_cdPtr),
                                // Zone parameter at calldata offset 0xa4.
                                calldataload(BasicOrder_zone_cdPtr)
                            ),
                            or(
                                // Offer token parameter at cd offset 0xc4.
                                calldataload(BasicOrder_offerToken_cdPtr),
                                // Consideration token parameter at offset 0x24.
                                calldataload(
                                    BasicOrder_considerationToken_cdPtr
                                )
                            )
                        ),
                        AddressDirtyUpperBitThreshold
                    )
                )
            )
        }

        // Revert with an error if basic order parameter offsets are invalid.
        if (!validOffsets) {
            _revertInvalidBasicOrderParameterEncoding();
        }
    }
}
