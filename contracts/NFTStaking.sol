// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./Token.sol";

contract NFTStaking is Ownable, IERC721Receiver {
    /// @dev struct to store a vault info for specific collection
    struct vaultInfo {
        IERC721Enumerable nft;
        Token rewardToken;
        string name;
        // TODO - add logic for implement different staking coefficients
        uint256 stakingCoeff;
    }

    vaultInfo[] public VaultInfo;

    /// @dev struct to store a stake's token, owner, and earning values
    struct Stake {
        uint24 tokenId;
        uint48 timestamp;
        address owner;
    }

    uint256 public totalStaked;
    mapping(uint256 => Stake) public vault;

    event NFTStaked(address owner, uint256 tokenId, uint256 value);
    event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
    event Claimed(address owner, uint256 amount);

    /// @notice Add new vault according to whitelist of collections
    function addVault(
        IERC721Enumerable _nft,
        Token _rewardToken,
        string calldata _name,
        uint256 _coeff
    ) external onlyOwner {
        VaultInfo.push(
            vaultInfo({nft: _nft, rewardToken: _rewardToken, name: _name, stakingCoeff: _coeff})
        );
    }

    /// @notice allow users to stake assets
    /// @dev Transfers staked NFT to contract address and add info to Stake struct
    function stake(uint256 _pid, uint256[] calldata tokenIds) external {
        uint256 tokenId;
        totalStaked += tokenIds.length;
        vaultInfo storage vaultid = VaultInfo[_pid];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            // TODO - change to custom error
            require(
                vaultid.nft.ownerOf(tokenId) == msg.sender,
                "not your token"
            );
            require(vault[tokenId].tokenId == 0, "already staked");

            vaultid.nft.transferFrom(msg.sender, address(this), tokenId);
            emit NFTStaked(msg.sender, tokenId, block.timestamp);

            vault[tokenId] = Stake({
                owner: msg.sender,
                tokenId: uint24(tokenId),
                timestamp: uint48(block.timestamp)
            });
        }
    }

    /// @dev Give back staked NFTs to user
    function _unstakeMany(
        address account,
        uint256[] calldata tokenIds,
        uint256 _pid
    ) internal {
        uint256 tokenId;
        totalStaked -= tokenIds.length;
        vaultInfo storage vaultid = VaultInfo[_pid];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            Stake memory staked = vault[tokenId];
            // TODO - change to custom error
            require(staked.owner == msg.sender, "not an owner");

            delete vault[tokenId];
            emit NFTUnstaked(account, tokenId, block.timestamp);
            vaultid.nft.transferFrom(address(this), account, tokenId);
        }
    }

    /// @notice Allow claim rewards and continue staking
    function claim(uint256[] calldata tokenIds, uint256 _pid) external {
        _claim(msg.sender, tokenIds, _pid, false);
    }

    // TODO - does this function need and for which purposes???
    function claimForAddress(
        address account,
        uint256[] calldata tokenIds,
        uint256 _pid
    ) external {
        _claim(account, tokenIds, _pid, false);
    }

    /// @notice Allow users claim rewards and get NFTs back
    function unstake(uint256[] calldata tokenIds, uint256 _pid) external {
        _claim(msg.sender, tokenIds, _pid, true);
    }

    /// @dev Update information in storage and mint rewards
    function _claim(
        address account,
        uint256[] calldata tokenIds,
        uint256 _pid,
        bool _unstake
    ) internal {
        uint256 tokenId;
        uint256 earned = 0;
        vaultInfo storage vaultid = VaultInfo[_pid];
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            Stake memory staked = vault[tokenId];
            // TODO - change to custom error
            require(staked.owner == account, "not an owner");
            uint256 stakedAt = staked.timestamp;
            // TODO - add custom rewards calculating (according to base APY)
            earned += (100000 ether * (block.timestamp - stakedAt)) / 1 days;
            vault[tokenId] = Stake({
                owner: account,
                tokenId: uint24(tokenId),
                timestamp: uint48(block.timestamp)
            });
        }
        if (earned > 0) {
            earned = earned / 10;
            vaultid.rewardToken.mintTo(account, earned);
        }
        if (_unstake) {
            _unstakeMany(account, tokenIds, _pid);
        }
        emit Claimed(account, earned);
    }

    /// @notice Get information about staking earning
    function earningInfo(uint256[] calldata tokenIds)
        external
        view
        returns (uint256[2] memory info)
    {
        uint256 tokenId;
        uint256 totalScore = 0;
        uint256 earned = 0;
        Stake memory staked = vault[tokenId];
        uint256 stakedAt = staked.timestamp;
        earned += (100000 ether * (block.timestamp - stakedAt)) / 1 days;
        uint256 earnRatePerSecond = (totalScore * 1 ether) / 1 days;
        earnRatePerSecond = earnRatePerSecond / 100000;
        // earned, earnRatePerSecond
        return [earned, earnRatePerSecond];
    }

    /// @dev should never be used inside of transaction because of gas fee
    function balanceOf(address account, uint256 _pid)
        public
        view
        returns (uint256)
    {
        uint256 balance = 0;
        vaultInfo storage vaultid = VaultInfo[_pid];
        uint256 supply = vaultid.nft.totalSupply();
        for (uint256 i = 1; i <= supply; i++) {
            if (vault[i].owner == account) {
                balance += 1;
            }
        }
        return balance;
    }

    /// @dev should never be used inside of transaction because of gas fee
    function tokensOfOwner(address account, uint256 _pid)
        public
        view
        returns (uint256[] memory ownerTokens)
    {
        vaultInfo storage vaultid = VaultInfo[_pid];
        uint256 supply = vaultid.nft.totalSupply();
        uint256[] memory tmp = new uint256[](supply);

        uint256 index = 0;
        for (uint256 tokenId = 1; tokenId <= supply; tokenId++) {
            if (vault[tokenId].owner == account) {
                tmp[index] = vault[tokenId].tokenId;
                index += 1;
            }
        }

        uint256[] memory tokens = new uint256[](index);
        for (uint256 i = 0; i < index; i++) {
            tokens[i] = tmp[i];
        }

        return tokens;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        // TODO - change to custom error
        require(from == address(0x0), "Cannot send nfts to Vault directly");
        return IERC721Receiver.onERC721Received.selector;
    }
}
