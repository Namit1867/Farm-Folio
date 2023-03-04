// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibFarmFacet} from "../libraries/LibFarmFacet.sol";
import {AppStorage, Modifiers, NftInfo, PoolInfo} from "../libraries/LibAppStorage.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibMeta} from "../libraries/LibMeta.sol";

contract FarmFacet is Modifiers {
    function farmStorage() internal pure returns (AppStorage storage fs) {
        return LibFarmFacet.farmStorage();
    }

    function PORT_TOKEN_ADDRESS() external view returns (address) {
        return LibFarmFacet.PORT_TOKEN_ADDRESS();
    }

    function burnAddress() external pure returns (address) {
        return LibFarmFacet.burnAddress;
    }

    function ownerPORTReward() external pure returns (uint) {
        return LibFarmFacet.ownerPORTReward;
    }

    function PORTMaxSupply() external pure returns (uint) {
        return LibFarmFacet.PORTMaxSupply;
    }

    function PORTPerBlock() external pure returns (uint) {
        return LibFarmFacet.PORTPerBlock;
    }

    function totalAllocPoint() external view returns (uint) {
        return LibFarmFacet.totalAllocPoint();
    }

    function nftInfo(
        uint pid,
        uint nftId
    ) external view returns (NftInfo memory info) {
        return LibFarmFacet.nftInfo(pid, nftId);
    }

    function poolInfo(uint pid) external view returns (PoolInfo memory info) {
        return LibFarmFacet.poolInfo(pid);
    }

    function poolLength() external view returns (uint256) {
        return LibFarmFacet.poolLength();
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)

    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat
    ) external onlyOwner {
        LibFarmFacet.add(_allocPoint, _want, _withUpdate, _strat);
    }

    // Update the given pool's PORT allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) external onlyOwner {
        LibFarmFacet.set(_pid, _allocPoint, _withUpdate);
    }

    function massUpdatePools() external {
        LibFarmFacet.massUpdatePools();
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) external {
        LibFarmFacet.updatePool(_pid);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) external view returns (uint256) {
        return LibFarmFacet.getMultiplier(_from, _to);
    }

    // View function to see pending PORT on frontend.
    function pendingPORT(
        uint256 _pid,
        uint nftId
    ) external view returns (uint256) {
        return LibFarmFacet.pendingPORT(_pid, nftId);
    }

    function claimRewards(
        uint[] memory nftIds,
        uint[][] memory poolIds
    ) external {
        LibFarmFacet.claimRewards(nftIds, poolIds);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(
        uint256 _pid,
        uint nftId
    ) external view returns (uint256) {
        return LibFarmFacet.stakedWantTokens(_pid, nftId);
    }

    function noOfPoolsInvested(uint tokenId) external view returns (uint) {
        return LibFarmFacet.noOfPoolsInvested(tokenId);
    }

    // Want tokens moved from user -> PORTFarm (PORT allocation) -> Strat (compounding)
    function deposit(
        uint256 _pid,
        uint256 _wantAmt,
        uint nftId,
        bool mintNFT
    ) external {
        LibFarmFacet.deposit(_pid, _wantAmt, nftId, mintNFT);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt, uint nftId) external {
        LibFarmFacet.withdraw(_pid, _wantAmt, nftId);
    }

    function withdrawAll(uint256 _pid, uint nftId) external {
        LibFarmFacet.withdrawAll(_pid, nftId);
    }

    function inCaseTokensGetStuck(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        LibFarmFacet.inCaseTokensGetStuck(_token, _amount);
    }

    function mergePortfolios(
        uint[] memory nftIds,
        uint[][] memory poolIds
    ) external {
        LibFarmFacet.mergePortfolios(nftIds, poolIds);
    }

    function unmergePortfolios(uint nftId, uint[] memory pools) external {
        LibFarmFacet.unmergePortfolios(nftId, pools);
    }
}
