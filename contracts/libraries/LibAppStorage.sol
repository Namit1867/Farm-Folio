// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {LibDiamond} from "./LibDiamond.sol";
import {IERC20} from "../libraries/SafeERC20.sol";
import {LibMeta} from "../libraries/LibMeta.sol";
import {LibNFT} from "../libraries/LibNFT.sol";

// Info of each nft.
struct NftInfo {
    uint256 shares; // How many LP tokens tagged with this NFT.
    uint256 rewardDebt; // Reward debt. See explanation below.

    // We do some fancy math here. Basically, any point in time, the amount of PORT
    // entitled to a NFT but is pending to be distributed is:
    //
    //   amount = nft.shares / sharesTotal * wantLockedTotal
    //   pending reward = (amount * pool.accPORTPerShare) - nft.rewardDebt
    //
    // Whenever a nft holder deposits or withdraws want tokens to a pool. Here's what happens:
    //   1. The pool's `accPORTPerShare` (and `lastRewardBlock`) gets updated.
    //   2. Nft receives the pending reward sent to his/her address.
    //   3. Nft's `amount` gets updated.
    //   4. Nft's `rewardDebt` gets updated.
}

struct PoolInfo {
    IERC20 want; // Address of the want token.
    uint256 allocPoint; // How many allocation points assigned to this pool. PORT to distribute per block.
    uint256 lastRewardBlock; // Last block number that PORT distribution occurs.
    uint256 accPORTPerShare; // Accumulated PORT per share, times 1e12. See below.
    address strat; // Strategy address that will auto compound want tokens
}

struct AppStorage {
    uint startBlock;
    address PORT_TOKEN_ADDRESS;
    PoolInfo[] poolInfo;
    mapping(uint256 => mapping(uint => NftInfo)) nftInfo; // NFT Info's.
    mapping(uint256 => uint256) noOfPoolsInvested; //no of pools in which investment is done through this nft
    uint totalAllocPoint;
}

library LibAppStorage {
    bytes32 constant APP_STORAGE_POSITION =
        keccak256("diamond.standard.app.storage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}

contract Modifiers {
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyInitialOwner(uint256 _tokenId) {
        require(LibNFT._exists(_tokenId), "Portfolio: NFT not exist");
        require(
            LibNFT.nftStorage().initialOwner[_tokenId] == LibMeta.msgSender(),
            "Portfolio: only initial owner can set the royalty"
        );
        _;
    }

    modifier isNFTOwner(uint256 _nftTokenId) {
        require(
            LibNFT.ownerOf(_nftTokenId) == LibMeta.msgSender(),
            "Portfolio: caller is not owner"
        );
        _;
    }

    modifier isApprovedOrOwner_(address spender, uint256 _nftTokenId) {
        require(
            LibNFT._isApprovedOrOwner(spender, _nftTokenId),
            "Portfolio: caller is not owner nor approved"
        );
        _;
    }
}
