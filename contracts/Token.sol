// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

/**
 *  This smart contract implements the ERC20 standard.
 *  It includes the following additions to standard ERC20 logic:
 *
 *      - Ability to mint & burn tokens via the provided `mint` & `burn` functions.
 *
 *      - Ownership of the contract, with the ability to restrict certain functions to
 *        only be called by the contract's owner.
 *
 *      - Multicall capability to perform multiple actions atomically
 *
 *      - EIP 2612 compliance: See {ERC20-permit} method, which can be used to change an account's ERC20 allowance by
 *                             presenting a message signed by the account.
 */

 error ErrorZeroMint();
 error ErrorInsufficientBurn(uint256 burnAmount, uint256 balance);

contract Token is ContractMetadata, Multicall, Ownable, ERC20Permit {
    constructor(string memory _name, string memory _symbol) ERC20Permit(_name) ERC20(_name, _symbol) {}
    
    /** 
     *  @notice          Lets an authorized address mint tokens to a recipient.
     *  @dev             The logic in the _canMint function determines whether the caller is authorized to mint tokens.
     *
     *  @param _to       The recipient of the tokens to mint.
     *  @param _amount   Quantity of tokens to mint.
     */
    function mintTo(address _to, uint256 _amount) public virtual onlyOwner {
        if (_amount == 0) {
            revert ErrorZeroMint();
        }

        _mint(_to, _amount);
    }

    /**
     *  @notice          Lets an owner a given amount of their tokens.
     *  @dev             Caller should own the _amount of tokens.
     *
     *  @param _amount   The number of tokens to burn.
     */
    function burn(uint256 _amount) external virtual {
        if (balanceOf(msg.sender) <= _amount) {
            revert ErrorInsufficientBurn(_amount, balanceOf(msg.sender));
        }
        _burn(msg.sender, _amount);
    }

    /// @dev Returns whether contract metadata can be set in the given execution context.
    function _canSetContractURI() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

}