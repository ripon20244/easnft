// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ItemType, OrderType } from "./ConsiderationEnums.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    OfferItem,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "./ConsiderationStructs.sol";

import { BasicOrderFulfiller } from "./BasicOrderFulfiller.sol";

import { CriteriaResolution } from "./CriteriaResolution.sol";

import { AmountDeriver } from "./AmountDeriver.sol";

import {
    _revertInsufficientNativeTokensSupplied,
    _revertInvalidNativeOfferItem
} from "./ConsiderationErrors.sol";

import {
    AccumulatorDisarmed,
    ConsiderationItem_recipient_offset,
    ReceivedItem_amount_offset,
    ReceivedItem_recipient_offset
} from "./ConsiderationConstants.sol";

/**
 * @title OrderFulfiller
 * @author 0age
 * @notice OrderFulfiller contains logic related to order fulfillment where a
 *         single order is being fulfilled and where basic order fulfillment is
 *         not available as an option.
 */
contract OrderFulfiller is
    BasicOrderFulfiller,
    CriteriaResolution,
    AmountDeriver
{
   
    constructor(
    ) BasicOrderFulfiller() {}


    /**
     * @dev Internal function to emit an OrderFulfilled event. OfferItems are
     *      translated into SpentItems and ConsiderationItems are translated
     *      into ReceivedItems.
     *
     * @param orderHash     The order hash.
     * @param offerer       The offerer for the order.
     * @param zone          The zone for the order.
     * @param recipient     The recipient of the order, or the null address if
     *                      the order was fulfilled via order matching.
     * @param offer         The offer items for the order.
     * @param consideration The consideration items for the order.
     */
    function _emitOrderFulfilledEvent(
        bytes32 orderHash,
        address offerer,
        address zone,
        address recipient,
        OfferItem[] memory offer,
        ConsiderationItem[] memory consideration
    ) internal {
        // Cast already-modified offer memory region as spent items.
        SpentItem[] memory spentItems;
        assembly {
            spentItems := offer
        }

        // Cast already-modified consideration memory region as received items.
        ReceivedItem[] memory receivedItems;
        assembly {
            receivedItems := consideration
        }

        // Emit an event signifying that the order has been fulfilled.
        emit OrderFulfilled(
            orderHash,
            offerer,
            zone,
            recipient,
            spentItems,
            receivedItems
        );
    }
}
