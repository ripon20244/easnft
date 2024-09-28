// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ConsiderationEventsAndErrors} from "../interfaces/ConsiderationEventsAndErrors.sol";

import {BulkOrder_Typehash_Height_One, BulkOrder_Typehash_Height_Two, BulkOrder_Typehash_Height_Three, BulkOrder_Typehash_Height_Four, BulkOrder_Typehash_Height_Five, BulkOrder_Typehash_Height_Six, BulkOrder_Typehash_Height_Seven, BulkOrder_Typehash_Height_Eight, BulkOrder_Typehash_Height_Nine, BulkOrder_Typehash_Height_Ten, BulkOrder_Typehash_Height_Eleven, BulkOrder_Typehash_Height_Twelve, BulkOrder_Typehash_Height_Thirteen, BulkOrder_Typehash_Height_Fourteen, BulkOrder_Typehash_Height_Fifteen, BulkOrder_Typehash_Height_Sixteen, BulkOrder_Typehash_Height_Seventeen, BulkOrder_Typehash_Height_Eighteen, BulkOrder_Typehash_Height_Nineteen, BulkOrder_Typehash_Height_Twenty, BulkOrder_Typehash_Height_TwentyOne, BulkOrder_Typehash_Height_TwentyTwo, BulkOrder_Typehash_Height_TwentyThree, BulkOrder_Typehash_Height_TwentyFour, EIP712_domainData_chainId_offset, EIP712_domainData_nameHash_offset, EIP712_domainData_size, EIP712_domainData_verifyingContract_offset, EIP712_domainData_versionHash_offset, FreeMemoryPointerSlot, NameLengthPtr, NameWithLength, OneWord, Slot0x80, ThreeWords, ZeroSlot} from "./ConsiderationConstants.sol";

import {ConsiderationDecoder} from "./ConsiderationDecoder.sol";

import {ConsiderationEncoder} from "./ConsiderationEncoder.sol";


contract ConsiderationBase is
    ConsiderationDecoder,
    ConsiderationEncoder,
    ConsiderationEventsAndErrors
{
    // Precompute hashes, original chainId, and domain separator on deployment.
    bytes32 internal immutable _NAME_HASH;
    bytes32 internal immutable _VERSION_HASH;
    bytes32 internal immutable _EIP_712_DOMAIN_TYPEHASH;
    bytes32 internal immutable _OFFER_ITEM_TYPEHASH;
    bytes32 internal immutable _CONSIDERATION_ITEM_TYPEHASH;
    bytes32 internal immutable _ORDER_TYPEHASH;
    uint256 internal immutable _CHAIN_ID;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    constructor() {
        // Derive name and version hashes alongside required EIP-712 typehashes.
        (
            _NAME_HASH,
            _VERSION_HASH,
            _EIP_712_DOMAIN_TYPEHASH,
            _OFFER_ITEM_TYPEHASH,
            _CONSIDERATION_ITEM_TYPEHASH,
            _ORDER_TYPEHASH
        ) = _deriveTypehashes();

        // Store the current chainId and derive the current domain separator.
        _CHAIN_ID = block.chainid;
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
    }

   
    function _deriveDomainSeparator()
        internal
        view
        returns (bytes32 domainSeparator)
    {
        bytes32 typehash = _EIP_712_DOMAIN_TYPEHASH;
        bytes32 nameHash = _NAME_HASH;
        bytes32 versionHash = _VERSION_HASH;

        // Leverage scratch space and other memory to perform an efficient hash.
        assembly {
            // Retrieve the free memory pointer; it will be replaced afterwards.
            let freeMemoryPointer := mload(FreeMemoryPointerSlot)

            // Retrieve value at 0x80; it will also be replaced afterwards.
            let slot0x80 := mload(Slot0x80)

            // Place typehash, name hash, and version hash at start of memory.
            mstore(0, typehash)
            mstore(EIP712_domainData_nameHash_offset, nameHash)
            mstore(EIP712_domainData_versionHash_offset, versionHash)

            // Place chainId in the next memory location.
            mstore(EIP712_domainData_chainId_offset, chainid())

            // Place the address of this contract in the next memory location.
            mstore(EIP712_domainData_verifyingContract_offset, address())

            // Hash relevant region of memory to derive the domain separator.
            domainSeparator := keccak256(0, EIP712_domainData_size)

            // Restore the free memory pointer.
            mstore(FreeMemoryPointerSlot, freeMemoryPointer)

            // Restore the zero slot to zero.
            mstore(ZeroSlot, 0)

            // Restore the value at 0x80.
            mstore(Slot0x80, slot0x80)
        }
    }

    
    function _name() internal pure virtual returns (string memory) {
        // Return the name of the contract.
        assembly {
            // First element is the offset for the returned string. Offset the
            // value in memory by one word so that the free memory pointer will
            // be overwritten by the next write.
            mstore(OneWord, OneWord)

            // Name is right padded, so it touches the length which is left
            // padded. This enables writing both values at once. The free memory
            // pointer will be overwritten in the process.
            mstore(NameLengthPtr, NameWithLength)

            // Standard ABI encoding pads returned data to the nearest word. Use
            // the already empty zero slot memory region for this purpose and
            // return the final name string, offset by the original single word.
            return(OneWord, ThreeWords)
        }
    }

  
    function _nameString() internal pure virtual returns (string memory) {
        // Return the name of the contract.
        return "";
    }

   
    function _deriveTypehashes()
        internal
        pure
        returns (
            bytes32 nameHash,
            bytes32 versionHash,
            bytes32 eip712DomainTypehash,
            bytes32 offerItemTypehash,
            bytes32 considerationItemTypehash,
            bytes32 orderTypehash
        )
    {
        // Derive hash of the name of the contract.
        nameHash = keccak256(bytes(_nameString()));

        // Derive hash of the version string of the contract.
        versionHash = keccak256(bytes("1.5"));

        // Construct the OfferItem type string.
        bytes memory offerItemTypeString = bytes(
            "OfferItem("
            "uint8 itemType,"
            "address token,"
            "uint256 identifierOrCriteria,"
            "uint256 startAmount,"
            "uint256 endAmount"
            ")"
        );

        // Construct the ConsiderationItem type string.
        bytes memory considerationItemTypeString = bytes(
            "ConsiderationItem("
            "uint8 itemType,"
            "address token,"
            "uint256 identifierOrCriteria,"
            "uint256 startAmount,"
            "uint256 endAmount,"
            "address recipient"
            ")"
        );

        // Construct the OrderComponents type string, not including the above.
        bytes memory orderComponentsPartialTypeString = bytes(
            "OrderComponents("
            "address offerer,"
            "address zone,"
            "OfferItem[] offer,"
            "ConsiderationItem[] consideration,"
            "uint8 orderType,"
            "uint256 startTime,"
            "uint256 endTime,"
            "bytes32 zoneHash,"
            "uint256 salt,"
            "bytes32 conduitKey,"
            "uint256 counter"
            ")"
        );

        // Construct the primary EIP-712 domain type string.
        eip712DomainTypehash = keccak256(
            bytes(
                "EIP712Domain("
                "string name,"
                "string version,"
                "uint256 chainId,"
                "address verifyingContract"
                ")"
            )
        );

        // Derive the OfferItem type hash using the corresponding type string.
        offerItemTypehash = keccak256(offerItemTypeString);

        // Derive ConsiderationItem type hash using corresponding type string.
        considerationItemTypehash = keccak256(considerationItemTypeString);

        bytes memory orderTypeString = bytes.concat(
            orderComponentsPartialTypeString,
            considerationItemTypeString,
            offerItemTypeString
        );

        // Derive OrderItem type hash via combination of relevant type strings.
        orderTypehash = keccak256(orderTypeString);
    }


}
