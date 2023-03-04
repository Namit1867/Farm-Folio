// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PORT is ERC20, Ownable {

    constructor(string memory _name,string memory _symbol) ERC20(_name,_symbol) {
        _mint(msg.sender, 100e18);
    }
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
