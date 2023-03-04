// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Stratx2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StratX2_AUTO is StratX2 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor(address[] memory _addresses) {
        wbnbAddress = _addresses[0];
        govAddress = _addresses[1];
        autoFarmAddress = _addresses[2];
        AUTOAddress = _addresses[3];
        wantAddress = _addresses[4];
        earnedAddress = _addresses[5];
        rewardsAddress = _addresses[6];
        buyBackAddress = _addresses[7];

        buyBackRate = 250;
        controllerFee = 70;

        transferOwnership(autoFarmAddress);
    }

    function deposit(
        address _userAddress,
        uint256 _wantAmt
    ) public override onlyOwner returns (uint256) {
        _userAddress;
        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        uint256 sharesAdded = _wantAmt;
        if (wantLockedTotal > 0 && sharesTotal > 0) {
            sharesAdded = _wantAmt
                .mul(sharesTotal)
                .mul(entranceFeeFactor)
                .div(wantLockedTotal)
                .div(entranceFeeFactorMax);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        wantLockedTotal = IERC20(wantAddress).balanceOf(address(this));

        return sharesAdded;
    }

    function withdraw(
        address _userAddress,
        uint256 _wantAmt
    ) public override onlyOwner returns (uint256) {
        _userAddress;
        require(_wantAmt > 0, "_wantAmt <= 0");

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal);
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);

        if (withdrawFeeFactor < withdrawFeeFactorMax) {
            _wantAmt = _wantAmt.mul(withdrawFeeFactor).div(
                withdrawFeeFactorMax
            );
        }

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (wantLockedTotal < _wantAmt) {
            _wantAmt = wantLockedTotal;
        }

        wantLockedTotal = wantLockedTotal.sub(_wantAmt);

        IERC20(wantAddress).safeTransfer(autoFarmAddress, _wantAmt);

        return sharesRemoved;
    }

    receive() external payable {}
}
