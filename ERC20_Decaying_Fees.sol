// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ERC20DecayingFees
 * @dev Implementation of an ERC20 token with a double linear tax reduction.
 * The tax rate decreases linearly to a breakpoint rate until the breakpoint time,
 * then decreases linearly to the final rate until the final time. This contract
 * applies these taxes to buy/sell transactions involving a designated liquidity pool.
 */
contract ERC20DecayingFees is ERC20, Ownable {
    uint256 public launchTime;
    uint256 public initialTax;     // The initial tax rate (e.g., 9900 for 99%)
    uint256 public breakpointTax;  // The tax rate at the breakpoint (e.g., 3000 for 30%)
    uint256 public breakpointTime; // The time when the tax rate reaches the breakpoint (e.g., 5 minutes)
    uint256 public finalTax;       // The final tax rate (e.g., 0 for 0%)
    uint256 public finalTaxTime;   // The time when the tax rate reaches the final rate (e.g., 30 minutes)
    address public liquidityPool; // Address of the designated liquidity pool

    uint256 private constant BASE = 10000; // Base to allow for percentages

    /**
     * @dev Sets the values for {name} and {symbol}, initializes the tax reduction variables.
     *
     * All five of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 _initialTax,
        uint256 _breakpointTax,
        uint256 _breakpointTime,
        uint256 _finalTax,
        uint256 _finalTaxTime
    ) ERC20(name, symbol) {
        initialTax = _initialTax;
        breakpointTax = _breakpointTax;
        breakpointTime = _breakpointTime * 60; // Convert minutes to seconds
        finalTax = _finalTax;
        finalTaxTime = _finalTaxTime * 60; // Convert minutes to seconds
        
        _mint(msg.sender, initialSupply); // Mint initial token supply to deployer
    }

    /**
     * @dev Sets the address of the liquidity pool.
     * This can only be called by the owner of the token.
     */
    function setLiquidityPool(address _lpAddress) external onlyOwner {
        require(_lpAddress != address(0), "Invalid LP address");
        require(liquidityPool == address(0), "LP already set");
        launchTime = block.timestamp;
        liquidityPool = _lpAddress;
    }

    /**
     * @dev Calculates the current tax based on the time elapsed since launch.
     * The tax decreases in two linear phases: from `initialTax` to `breakpointTax`,
     * and then from `breakpointTax` to `finalTax`.
     */
    function getCurrentTax() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - launchTime;

        if (timeElapsed >= finalTaxTime) {
            return finalTax; // No tax after final tax time
        } else if (timeElapsed < breakpointTime) {
            // Tax decreases from initialTax to breakpointTax until breakpointTime
            uint256 taxDrop = (initialTax - breakpointTax) * timeElapsed / breakpointTime;
            return initialTax - taxDrop;
        } else {
            // Tax decreases from breakpointTax to finalTax from breakpointTime to finalTaxTime
            uint256 taxDrop = (breakpointTax - finalTax) * (timeElapsed - breakpointTime) / (finalTaxTime - breakpointTime);
            return breakpointTax - taxDrop;
        }
    }

    /**
     * @dev Override the standard ERC20 transfer function to include tax logic.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        bool applyTax = (sender == liquidityPool || recipient == liquidityPool) && liquidityPool != address(0);
        uint256 taxAmount = 0;

        if (applyTax) {
            uint256 currentTax = getCurrentTax();
            taxAmount = (amount * currentTax) / BASE;
        }

        uint256 amountAfterTax = amount - taxAmount;

        super._transfer(sender, recipient, amountAfterTax);

        // If there's a tax, handle it (e.g., burn it)
        if(taxAmount > 0) {
            _burn(sender, taxAmount);
        }
    }
}