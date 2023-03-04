// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    bytes32 constant COUNTER_STORAGE_POSITION =
        keccak256("diamond.standard.counter.storage");

    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function counterStorage() internal pure returns (Counter storage cs) {
        bytes32 position = COUNTER_STORAGE_POSITION;
        assembly {
            cs.slot := position
        }
    }

    function current() internal view returns (uint256) {
        Counter storage cs = counterStorage();
        return cs._value;
    }

    function increment() internal {
        unchecked {
            Counter storage cs = counterStorage();
            cs._value += 1;
        }
    }

    function decrement() internal {
        Counter storage cs = counterStorage();
        uint256 value = cs._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            cs._value = cs._value - 1;
        }
    }

    function reset() internal {
        Counter storage cs = counterStorage();
        cs._value = 0;
    }
}
