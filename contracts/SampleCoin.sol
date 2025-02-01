// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract SampleCoin is ERC20, Ownable {
    // your code goes here (you can do it!)
    /**
     * @notice Constructor for the SampleCoin contract which mints 100 * 10 ** 18 tokens to the contract owner.
     */
    constructor() ERC20("SampleCoin", "SC") Ownable(msg.sender) {
        _mint(msg.sender, 100 * 10 ** 18);
    }

    /**
     * @notice Mints new tokens, only callable by the contract owner.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to be minted.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Allows users to burn their own tokens.
     * @param amount The amount of tokens to burn.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}