// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ConsiderationInterface} from "../interfaces/ConsiderationInterface.sol";

import {AdvancedOrder, BasicOrderParameters, CriteriaResolver, Execution, Fulfillment, FulfillmentComponent, Order, OrderComponents} from "./ConsiderationStructs.sol";

import {OrderCombiner} from "./OrderCombiner.sol";

import {CalldataStart, CalldataPointer} from "../helpers/PointerLibraries.sol";

import {Offset_fulfillAdvancedOrder_criteriaResolvers, Offset_fulfillAvailableOrders_considerationFulfillments, Offset_fulfillAvailableOrders_offerFulfillments, Offset_matchAdvancedOrders_criteriaResolvers, Offset_matchAdvancedOrders_fulfillments, Offset_matchOrders_fulfillments, OrderParameters_counter_offset} from "./ConsiderationConstants.sol";
/**
 * @title Consideration
 * @author 0age (0age.eth)
 * @notice Consideration is a generalized native token/ERC20/ERC721/ERC1155
 *         marketplace that provides lightweight methods for common routes as
 *         well as more flexible methods for composing advanced orders or groups
 *         of orders. Each order contains an arbitrary number of items that may
 *         be spent (the "offer") along with an arbitrary number of items that
 *         must be received back by the indicated recipients (the
 *         "consideration").
 */

contract Consideration is ConsiderationInterface, OrderCombiner {
    constructor() OrderCombiner() {}

    /**
     * @notice Accept native token transfers during execution that may then be
     *         used to facilitate native token transfers, where any tokens that
     *         remain will be transferred to the caller. Native tokens are only
     *         acceptable mid-fulfillment (and not during basic fulfillment).
     */
    receive() external payable {
        // Ensure the reentrancy guard is currently set to accept native tokens.
        _assertAcceptingNativeTokens();
    }

    /**
     * @notice Fulfill an order offering an ERC20, ERC721, or ERC1155 item by
     *         supplying Ether (or other native tokens), ERC20 tokens, an ERC721
     *         item, or an ERC1155 item as consideration. Six permutations are
     *         supported: Native token to ERC721, Native token to ERC1155, ERC20
     *         to ERC721, ERC20 to ERC1155, ERC721 to ERC20, and ERC1155 to
     *         ERC20 (with native tokens supplied as msg.value). For an order to
     *         be eligible for fulfillment via this method, it must contain a
     *         single offer item (though that item may have a greater amount if
     *         the item is not an ERC721). An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive native
     *         tokens or ERC20 items from the fulfiller as consideration. Refer
     *         to the documentation for a more comprehensive summary of how to
     *         utilize this method and what orders are compatible with it.
     *
     * @custom:param parameters Additional information on the fulfilled order.
     *                          Note that the offerer and the fulfiller must
     *                          first approve this contract (or their chosen
     *                          conduit if indicated) before any tokens can be
     *                          transferred. Also note that contract recipients
     *                          of ERC1155 consideration items must implement
     *                          `onERC1155Received` to receive those items.
     *
     * @return fulfilled A boolean indicating whether the order has been
     *                   successfully fulfilled.
     */

    /**
     * @notice Fulfill an order offering an ERC20, ERC721, or ERC1155 item by
     *         supplying Ether (or other native tokens), ERC20 tokens, an ERC721
     *         item, or an ERC1155 item as consideration. Six permutations are
     *         supported: Native token to ERC721, Native token to ERC1155, ERC20
     *         to ERC721, ERC20 to ERC1155, ERC721 to ERC20, and ERC1155 to
     *         ERC20 (with native tokens supplied as msg.value). For an order to
     *         be eligible for fulfillment via this method, it must contain a
     *         single offer item (though that item may have a greater amount if
     *         the item is not an ERC721). An arbitrary number of "additional
     *         recipients" may also be supplied which will each receive native
     *         tokens or ERC20 items from the fulfiller as consideration. Refer
     *         to the documentation for a more comprehensive summary of how to
     *         utilize this method and what orders are compatible with it. Note
     *         that this function costs less gas than `fulfillBasicOrder` due to
     *         the zero bytes in the function selector (0x00000000) which also
     *         results in earlier function dispatch.
     *
     * @custom:param parameters Additional information on the fulfilled order.
     *                          Note that the offerer and the fulfiller must
     *                          first approve this contract (or their chosen
     *                          conduit if indicated) before any tokens can be
     *                          transferred. Also note that contract recipients
     *                          of ERC1155 consideration items must implement
     *                          `onERC1155Received` to receive those items.
     *
     * @return fulfilled A boolean indicating whether the order has been
     *                   successfully fulfilled.
     */

    function fulfillBasicOrder(
        BasicOrderParameters calldata parameters
    ) external payable override returns (bool fulfilled) {
        // Validate and fulfill the basic order.
        fulfilled = _validateAndFulfillBasicOrder(parameters);
    }

    /**
     * @notice Match an arbitrary number of orders, each with an arbitrary
     *         number of items for offer and consideration along with a set of
     *         fulfillments allocating offer components to consideration
     *         components. Note that this function does not support
     *         criteria-based or partial filling of orders (though filling the
     *         remainder of a partially-filled order is supported). Any unspent
     *         offer item amounts or native tokens will be transferred to the
     *         caller.
     *
     * @custom:param orders       The orders to match. Note that both the
     *                            offerer and fulfiller on each order must first
     *                            approve this contract (or their conduit if
     *                            indicated by the order) to transfer any
     *                            relevant tokens on their behalf and each
     *                            consideration recipient must implement
     *                            `onERC1155Received` to receive ERC1155 tokens.
     * @custom:param fulfillments An array of elements allocating offer
     *                            components to consideration components. Note
     *                            that each consideration component must be
     *                            fully met for the match operation to be valid,
     *                            and that any unspent offer items will be sent
     *                            unaggregated to the caller.
     *
     * @return executions An array of elements indicating the sequence of
     *                    transfers performed as part of matching the given
     *                    orders. Note that unspent offer item amounts or native
     *                    tokens will not be reflected as part of this array.
     */

    function matchOrders(
        /**
         * @custom:name orders
         */
        Order[] calldata,
        /**
         * @custom:name fulfillments
         */
        Fulfillment[] calldata
    ) external payable override returns (Execution[] memory /* executions */) {
        // Convert to advanced, validate, and match orders using fulfillments.
        return
            _matchAdvancedOrders(
                _toAdvancedOrdersReturnType(_decodeOrdersAsAdvancedOrders)(
                    CalldataStart.pptr()
                ),
                new CriteriaResolver[](0), // No criteria resolvers supplied.
                _toFulfillmentsReturnType(_decodeFulfillments)(
                    CalldataStart.pptr(Offset_matchOrders_fulfillments)
                ),
                msg.sender
            );
    }


    /**
     * @notice Cancel an arbitrary number of orders. Note that only the offerer
     *         or the zone of a given order may cancel it. Callers should ensure
     *         that the intended order was cancelled by calling `getOrderStatus`
     *         and confirming that `isCancelled` returns `true`.
     *
     * @param orders The orders to cancel.
     *
     * @return cancelled A boolean indicating whether the supplied orders have
     *                   been successfully cancelled.
     */
    function cancel(
        OrderComponents[] calldata orders
    ) external override returns (bool cancelled) {
        // Cancel the orders.
        cancelled = _cancel(orders);
    }

    /**
     * @notice Validate an arbitrary number of orders, thereby registering their
     *         signatures as valid and allowing the fulfiller to skip signature
     *         verification on fulfillment. Note that validated orders may still
     *         be unfulfillable due to invalid item amounts or other factors;
     *         callers should determine whether validated orders are fulfillable
     *         by simulating the fulfillment call prior to execution. Also note
     *         that anyone can validate a signed order, but only the offerer can
     *         validate an order without supplying a signature.
     *
     * @custom:param orders The orders to validate.
     *
     * @return validated A boolean indicating whether the supplied orders have
     *                   been successfully validated.
     */
    function validate(
        /**
         * @custom:name orders
         */
        Order[] calldata
    ) external override returns (bool /* validated */) {
        return
            _validate(_toOrdersReturnType(_decodeOrders)(CalldataStart.pptr()));
    }

    /**
     * @notice Cancel all orders from a given offerer with a given zone in bulk
     *         by incrementing a counter. Note that only the offerer may
     *         increment the counter.
     *
     * @return newCounter The new counter.
     */
    function incrementCounter() external override returns (uint256 newCounter) {
        // Increment current counter for the supplied offerer.  Note that the
        // counter is incremented by a large, quasi-random interval.
        newCounter = _incrementCounter();
    }

    /**
     * @notice Retrieve the order hash for a given order.
     *
     * @custom:param order The components of the order.
     *
     * @return orderHash The order hash.
     */
    function getOrderHash(
        /**
         * @custom:name order
         */
        OrderComponents calldata
    ) external view override returns (bytes32 orderHash) {
        CalldataPointer orderPointer = CalldataStart.pptr();

        // Derive order hash by supplying order parameters along with counter.
        orderHash = _deriveOrderHash(
            _toOrderParametersReturnType(
                _decodeOrderComponentsAsOrderParameters
            )(orderPointer),
            // Read order counter
            orderPointer.offset(OrderParameters_counter_offset).readUint256()
        );
    }

    /**
     * @notice Retrieve the status of a given order by hash, including whether
     *         the order has been cancelled or validated and the fraction of the
     *         order that has been filled. Since the _orderStatus[orderHash]
     *         does not get set for contract orders, getOrderStatus will always
     *         return (false, false, 0, 0) for those hashes. Note that this
     *         function is susceptible to view reentrancy and so should be used
     *         with care when calling from other contracts.
     *
     * @param orderHash The order hash in question.
     *
     * @return isValidated A boolean indicating whether the order in question
     *                     has been validated (i.e. previously approved or
     *                     partially filled).
     * @return isCancelled A boolean indicating whether the order in question
     *                     has been cancelled.
     * @return totalFilled The total portion of the order that has been filled
     *                     (i.e. the "numerator").
     * @return totalSize   The total size of the order that is either filled or
     *                     unfilled (i.e. the "denominator").
     */
    function getOrderStatus(
        bytes32 orderHash
    )
        external
        view
        override
        returns (
            bool isValidated,
            bool isCancelled,
            uint256 totalFilled,
            uint256 totalSize
        )
    {
        // Retrieve the order status using the order hash.
        return _getOrderStatus(orderHash);
    }
    /**
     * @notice Retrieve the current counter for a given offerer.
     *
     * @param offerer The offerer in question.
     *
     * @return counter The current counter.
     */

    function getCounter(
        address offerer
    ) external view override returns (uint256 counter) {
        // Return the counter for the supplied offerer.
        counter = _getCounter(offerer);
    }

    /**
     * @notice Retrieve configuration information for this contract.
     *
     * @return domainSeparator   The domain separator for this contract.
     */
    function information()
        external
        view
        override
        returns (bytes32 domainSeparator)
    {
        // Return the information for this contract.
        return _information();
    }

    /**
     * @dev Gets the contract offerer nonce for the specified contract offerer.
     *      Note that this function is susceptible to view reentrancy and so
     *      should be used with care when calling from other contracts.
     *
     * @param contractOfferer The contract offerer for which to get the nonce.
     *
     * @return nonce The contract offerer nonce.
     */
    function getContractOffererNonce(
        address contractOfferer
    ) external view override returns (uint256 nonce) {
        nonce = _contractNonces[contractOfferer];
    }
    /**
     * @notice Retrieve the name of this contract.
     *
     * @return contractName The name of this contract.
     */

    function name()
        external
        pure
        override
        returns (string memory /* contractName */)
    {
        // Return the name of the contract.
        return _name();
    }
}
