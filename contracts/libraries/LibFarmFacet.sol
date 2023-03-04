// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeMath} from "./LibSafeMath.sol";
import {LibAppStorage, AppStorage, PoolInfo, NftInfo} from "./LibAppStorage.sol";
import {SafeERC20, IERC20} from "../libraries/SafeERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {LibMeta} from "./LibMeta.sol";
import {LibNFT} from "./LibNFT.sol";

library LibFarmFacet {
    using SafeERC20 for IERC20;

    using SafeMath for uint256;

    uint256 public constant ownerPORTReward = 138; // 12%

    uint256 public constant PORTMaxSupply = 80000e18;

    uint256 public constant PORTPerBlock = 8000000000000000; // PORT tokens created per block

    address public constant burnAddress =
        0x000000000000000000000000000000000000dEaD;

    event Deposit(uint indexed nftId, uint256 indexed pid, uint256 amount);

    event Withdraw(uint indexed nftId, uint256 indexed pid, uint256 amount);

    event PoolAdded(uint allocPoint,IERC20 want,bool withUpdate,address strat);

    event PoolAllocSet(uint pid,uint allocPoint,uint newAllocPoint,bool withUpdate);

    event PoolRewardUpdated(uint poolId,uint newAccAutoPerShare);

    event ClaimPoolRewards(uint nftId,uint poolId);

    event MergePortFolio(uint nftId,uint newNftId,uint[] poolIds,bool burn_);

    event UnmergePortfolio(uint nftId,uint newNftId,uint[] poolIds);

    function farmStorage() internal pure returns (AppStorage storage fs) {
        return LibAppStorage.diamondStorage();
    }

    function PORT_TOKEN_ADDRESS() internal view returns (address) {
        AppStorage storage fs = farmStorage();
        return fs.PORT_TOKEN_ADDRESS;
    }

    function startBlock() internal view returns (uint) {
        AppStorage storage fs = farmStorage();
        return fs.startBlock;
    }

    function totalAllocPoint() internal view returns (uint256) {
        AppStorage storage fs = farmStorage();
        return fs.totalAllocPoint;
    }

    function poolLength() internal view returns (uint256) {
        AppStorage storage fs = farmStorage();
        return fs.poolInfo.length;
    }

    function poolInfo(uint pid) internal view returns (PoolInfo memory info) {
        AppStorage storage fs = farmStorage();
        info = fs.poolInfo[pid];
    }

    function nftInfo(
        uint pid,
        uint nftId
    ) internal view returns (NftInfo memory info) {
        AppStorage storage fs = farmStorage();
        info = fs.nftInfo[pid][nftId];
    }

    function initialize(
        address _PORT_TOKEN_ADDRESS,
        uint _startBlock
    ) internal {
        AppStorage storage fs = farmStorage();
        fs.PORT_TOKEN_ADDRESS = _PORT_TOKEN_ADDRESS;
        fs.startBlock = _startBlock;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do. (Only if want tokens are stored here.)
    function add(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat
    ) internal {
        AppStorage storage fs = farmStorage();

        if (_withUpdate) {
            massUpdatePools();
        }

        uint256 lastRewardBlock = block.number > fs.startBlock
            ? block.number
            : fs.startBlock;

        fs.totalAllocPoint = fs.totalAllocPoint.add(_allocPoint);

        fs.poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPORTPerShare: 0,
                strat: _strat
            })
        );

        emit PoolAdded(_allocPoint,_want,_withUpdate,_strat);
    }

    // Update the given pool's PORT allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) internal {
        AppStorage storage fs = farmStorage();

        if (_withUpdate) {
            massUpdatePools();
        }

        uint prevAlloc = fs.poolInfo[_pid].allocPoint;

        fs.totalAllocPoint = fs
            .totalAllocPoint
            .sub(fs.poolInfo[_pid].allocPoint)
            .add(_allocPoint);
        fs.poolInfo[_pid].allocPoint = _allocPoint;

       emit PoolAllocSet(_pid,prevAlloc,_allocPoint,_withUpdate);
    }

    function massUpdatePools() internal {
        AppStorage storage fs = farmStorage();
        uint256 length = fs.poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) internal {
        AppStorage storage fs = farmStorage();

        PoolInfo storage pool = fs.poolInfo[_pid];

        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();

        if (sharesTotal == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);

        if (multiplier <= 0) {
            return;
        }

        uint256 PORTReward = multiplier
            .mul(PORTPerBlock)
            .mul(pool.allocPoint)
            .div(fs.totalAllocPoint);

        IERC20(fs.PORT_TOKEN_ADDRESS).mint(
            LibDiamond.contractOwner(),
            PORTReward.mul(ownerPORTReward).div(1000)
        );
        IERC20(fs.PORT_TOKEN_ADDRESS).mint(address(this), PORTReward);

        pool.accPORTPerShare = pool.accPORTPerShare.add(
            PORTReward.mul(1e12).div(sharesTotal)
        );

        pool.lastRewardBlock = block.number;

        emit PoolRewardUpdated(_pid,pool.accPORTPerShare);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) internal view returns (uint256) {
        AppStorage storage fs = farmStorage();
        if (IERC20(fs.PORT_TOKEN_ADDRESS).totalSupply() >= PORTMaxSupply) {
            return 0;
        }
        return _to.sub(_from);
    }

    // View function to see pending PORT on frontend.
    function pendingPORT(
        uint256 _pid,
        uint nftId
    ) internal view returns (uint256) {
        AppStorage storage fs = farmStorage();

        PoolInfo storage pool = fs.poolInfo[_pid];
        NftInfo storage nft = fs.nftInfo[_pid][nftId];

        uint256 accPORTPerShare = pool.accPORTPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();

        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );

            uint256 PORTReward = multiplier
                .mul(PORTPerBlock)
                .mul(pool.allocPoint)
                .div(fs.totalAllocPoint);

            accPORTPerShare = accPORTPerShare.add(
                PORTReward.mul(1e12).div(sharesTotal)
            );
        }

        return nft.shares.mul(accPORTPerShare).div(1e12).sub(nft.rewardDebt);
    }

    // Want tokens moved from user -> PORTFarm (PORT allocation) -> Strat (compounding)
    function deposit(
        uint256 _pid,
        uint256 _wantAmt,
        uint nftId,
        bool mintNFT
    ) internal {
        AppStorage storage fs = farmStorage();

        //Update Pool Rewards
        updatePool(_pid);

        PoolInfo storage pool = fs.poolInfo[_pid];

        address broker;
        address nftOwner;

        //Broker Check
        if (mintNFT) {
            nftOwner = LibMeta.msgSender();
            nftId = LibNFT.safeMint(LibMeta.msgSender());
        } else {
            nftOwner = LibNFT.ownerOf(nftId);
            broker = LibNFT.brokerOf(nftId, _pid);
            if (broker != address(0))
                require(
                    broker == LibMeta.msgSender(),
                    "Portfolio :: Not the broker"
                );
            else
                require(
                    nftOwner == LibMeta.msgSender(),
                    "Portfolio :: Not the owner"
                );
        }

        NftInfo storage nft = fs.nftInfo[_pid][nftId];

        //Pending Rewards Transfer
        if (nft.shares > 0) {
            uint256 pending = nft
                .shares
                .mul(pool.accPORTPerShare)
                .div(1e12)
                .sub(nft.rewardDebt);
            if (pending > 0) {
                if (broker != address(0)) {
                    uint brokerPercentage = LibNFT.brokerage(nftId, _pid);
                    uint brokerShare = pending.mul(brokerPercentage).div(10000);
                    safePORTTransfer(broker, brokerShare);
                    pending = pending.sub(brokerShare);
                }

                safePORTTransfer(nftOwner, pending);
            }
        } else {
            fs.noOfPoolsInvested[nftId] = fs.noOfPoolsInvested[nftId] + 1;
        }

        if (_wantAmt > 0) {
            pool.want.safeTransferFrom(
                address(LibMeta.msgSender()),
                address(this),
                _wantAmt
            );

            pool.want.safeIncreaseAllowance(pool.strat, _wantAmt);
            uint256 sharesAdded = IStrategy(fs.poolInfo[_pid].strat).deposit(
                LibMeta.msgSender(),
                _wantAmt
            );
            nft.shares = nft.shares.add(sharesAdded);
        }
        nft.rewardDebt = nft.shares.mul(pool.accPORTPerShare).div(1e12);
        emit Deposit(nftId, _pid, _wantAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt, uint nftId) internal {
        AppStorage storage fs = farmStorage();

        updatePool(_pid);

        PoolInfo storage pool = fs.poolInfo[_pid];
        NftInfo storage nft = fs.nftInfo[_pid][nftId];

        address broker;
        address nftOwner;

        nftOwner = LibNFT.ownerOf(nftId);
        broker = LibNFT.brokerOf(nftId, _pid);
        if (broker != address(0))
            require(
                broker == LibMeta.msgSender(),
                "Portfolio :: Not the broker"
            );
        else
            require(
                nftOwner == LibMeta.msgSender(),
                "Portfolio :: Not the owner"
            );

        uint256 wantLockedTotal = IStrategy(fs.poolInfo[_pid].strat)
            .wantLockedTotal();
        uint256 sharesTotal = IStrategy(fs.poolInfo[_pid].strat).sharesTotal();

        require(nft.shares > 0, "nft.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw pending PORT
        uint256 pending = nft.shares.mul(pool.accPORTPerShare).div(1e12).sub(
            nft.rewardDebt
        );

        if (pending > 0) {
            if (broker != address(0)) {
                uint brokerPercentage = LibNFT.brokerage(nftId, _pid);
                uint brokerShare = pending.mul(brokerPercentage).div(10000);
                safePORTTransfer(broker, brokerShare);
                pending = pending.sub(brokerShare);
            }

            safePORTTransfer(nftOwner, pending);
        }

        // Withdraw want tokens
        uint256 amount = nft.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }

        if (_wantAmt > 0) {
            uint256 sharesRemoved = IStrategy(fs.poolInfo[_pid].strat).withdraw(
                LibMeta.msgSender(),
                _wantAmt
            );

            if (sharesRemoved > nft.shares) {
                nft.shares = 0;
                fs.noOfPoolsInvested[nftId] = fs.noOfPoolsInvested[nftId] - 1;
            } else {
                nft.shares = nft.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            pool.want.safeTransfer(nftOwner, _wantAmt);
        }
        nft.rewardDebt = nft.shares.mul(pool.accPORTPerShare).div(1e12);
        emit Withdraw(nftId, _pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid, uint _nftId) internal {
        withdraw(_pid, type(uint256).max, _nftId);
    }

    function claimRewards(
        uint[] memory nftIds,
        uint[][] memory poolIds
    ) internal {
        for (uint i = 0; i < nftIds.length; ++i) {
            uint nftId = nftIds[i];
            uint[] memory pools = poolIds[i];

            for (uint j = 0; j < pools.length; j++) {
                //claim pending rewards
                claimRewardInternal(nftId, pools[j]);
            }
        }
    }

    function claimRewardInternal(uint nftId, uint poolId) internal {
        AppStorage storage fs = farmStorage();

        updatePool(poolId);

        PoolInfo storage pool = fs.poolInfo[poolId];
        NftInfo storage nft = fs.nftInfo[poolId][nftId];

        address broker = LibNFT.brokerOf(nftId, poolId);

        if (nft.shares > 0) {
            uint256 pending = nft
                .shares
                .mul(pool.accPORTPerShare)
                .div(1e12)
                .sub(nft.rewardDebt);
            if (pending > 0) {
                if (broker != address(0)) {
                    uint brokerPercentage = LibNFT.brokerage(nftId, poolId);
                    uint brokerShare = pending.mul(brokerPercentage).div(10000);
                    safePORTTransfer(broker, brokerShare);
                    pending = pending.sub(brokerShare);
                }
                safePORTTransfer(LibMeta.msgSender(), pending);
            }
        }
        emit ClaimPoolRewards(nftId,poolId);
    }

    // Safe PORT transfer function, just in case if rounding error causes pool to not have enough
    function safePORTTransfer(address _to, uint256 _PORTAmt) internal {
        AppStorage storage fs = farmStorage();
        uint256 PORTBal = IERC20(fs.PORT_TOKEN_ADDRESS).balanceOf(
            address(this)
        );
        if (_PORTAmt > PORTBal) {
            IERC20(fs.PORT_TOKEN_ADDRESS).transfer(_to, PORTBal);
        } else {
            IERC20(fs.PORT_TOKEN_ADDRESS).transfer(_to, _PORTAmt);
        }
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(
        uint256 _pid,
        uint nftId
    ) internal view returns (uint256) {
        AppStorage storage fs = farmStorage();

        PoolInfo storage pool = fs.poolInfo[_pid];
        NftInfo storage nft = fs.nftInfo[_pid][nftId];

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 wantLockedTotal = IStrategy(fs.poolInfo[_pid].strat)
            .wantLockedTotal();

        if (sharesTotal == 0) {
            return 0;
        }

        return nft.shares.mul(wantLockedTotal).div(sharesTotal);
    }

    function noOfPoolsInvested(uint nftId) internal view returns (uint256) {
        AppStorage storage fs = farmStorage();
        return fs.noOfPoolsInvested[nftId];
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount) internal {
        AppStorage storage fs = farmStorage();
        require(_token != fs.PORT_TOKEN_ADDRESS, "!safe");
        IERC20(_token).safeTransfer(LibMeta.msgSender(), _amount);
    }

    function mergePortfolios(
        uint[] memory nftIds,
        uint[][] memory poolIds
    ) internal {
        AppStorage storage fs = farmStorage();

        require(nftIds.length == poolIds.length, "length mismatch");
        uint newNftId = LibNFT.safeMint(LibMeta.msgSender());

        for (uint i = 0; i < nftIds.length; ++i) {
            uint nftId = nftIds[i];
            uint[] memory pools = poolIds[i];

            //Ownership check
            require(
                LibNFT.ownerOf(nftId) == LibMeta.msgSender(),
                "Portfolio :: Not the owner"
            );

            //Royalty Checks
            LibNFT.NFTStorage storage ns = LibNFT.nftStorage();
            require(
                ns.initialOwner[nftId] == LibMeta.msgSender(),
                "Portfolio :: Not the initial owner"
            );

            // Rental Checks
            require(
                LibNFT.userOf(nftId) == address(0),
                "Portfolio is in renting"
            );

            //check each pool id is unique for this nft (pending)

            for (uint j = 0; j < pools.length; j++) {
                // Brokerage Check
                require(
                    LibNFT.brokerOf(nftId, pools[j]) == address(0),
                    "Pool is in brokerage"
                );

                //claim pending rewards
                claimRewardInternal(nftId, pools[j]);

                NftInfo storage oldShares = fs.nftInfo[pools[j]][nftId];
                NftInfo storage newShares = fs.nftInfo[pools[j]][newNftId];
                PoolInfo memory pool = fs.poolInfo[pools[j]];

                require(oldShares.shares > 0, "PorFolio :: No shares");

                if (newShares.shares == 0 && oldShares.shares > 0)
                    fs.noOfPoolsInvested[newNftId] =
                        fs.noOfPoolsInvested[newNftId] +
                        1;

                newShares.shares = newShares.shares + oldShares.shares;
                newShares.rewardDebt = newShares
                    .shares
                    .mul(pool.accPORTPerShare)
                    .div(1e12);

                delete oldShares.shares;
                delete oldShares.rewardDebt;

                fs.noOfPoolsInvested[nftId] = fs.noOfPoolsInvested[nftId] - 1;
            }

            if (fs.noOfPoolsInvested[nftId] == 0) {
                //destroy nft if noOfPoolsInvested is 0 for this nft
                //delete royalty info
                //delete rental info
                LibNFT._burn(nftId);
                emit MergePortFolio(nftId,newNftId,pools,true);
            }
            else{
                emit MergePortFolio(nftId,newNftId,pools,false);
            }
        }
    }

    function unmergePortfolios(uint nftId, uint[] memory pools) internal {
        AppStorage storage fs = farmStorage();

        address nftOwner = LibNFT.ownerOf(nftId);
        require(nftOwner == LibMeta.msgSender(), "Portfolio :: Not the owner");

        uint newNftId = LibNFT.safeMint(LibMeta.msgSender());

        for (uint i = 0; i < pools.length; ++i) {
            // Rental Checks
            require(
                LibNFT.userOf(nftId) == address(0),
                "Portfolio is in renting"
            );

            //check each pool id is unique for this nft (pending)

            // Brokerage Check
            require(
                LibNFT.brokerOf(nftId, pools[i]) == address(0),
                "Pool is in brokerage"
            );

            //claim pending rewards
            claimRewardInternal(nftId, pools[i]);

            NftInfo storage oldShares = fs.nftInfo[pools[i]][nftId];
            NftInfo storage newShares = fs.nftInfo[pools[i]][newNftId];
            PoolInfo memory pool = fs.poolInfo[pools[i]];

            require(oldShares.shares > 0, "PorFolio :: No shares");

            newShares.shares = newShares.shares + oldShares.shares;
            newShares.rewardDebt = newShares
                .shares
                .mul(pool.accPORTPerShare)
                .div(1e12);

            delete oldShares.shares;
            delete oldShares.rewardDebt;

            fs.noOfPoolsInvested[nftId] = fs.noOfPoolsInvested[nftId] - 1;

            fs.noOfPoolsInvested[newNftId] = fs.noOfPoolsInvested[newNftId] + 1;
        }

        emit UnmergePortfolio(nftId,newNftId,pools);
    }
}
