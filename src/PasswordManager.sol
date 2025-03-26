// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {console} from "forge-std/console.sol";

contract PasswordManager is ERC721 {
    /**
     * Errors
     */
    error PasswordManager__NotTheOwner();
    error PasswordManager__TokenDoesNotExist();
    error PasswordManager__EmptyInput();

    /**
     * Events
     */
    event PasswordAdded(uint256 indexed tokenId, string website);
    event PasswordUpdated(uint256 indexed tokenId, string website);
    event PasswordDeleted(uint256 indexed tokenId);

    /**
     * Types
     */
    // Struct to store password entry details
    struct PasswordEntry {
        string website;
        string encryptedUsername;
        string encryptedPassword;
        string message; // Store the message used for signing
        uint256 tokenId;
    }

    // Mapping from token ID to PasswordEntry
    mapping(uint256 => PasswordEntry) private s_passwordEntries;

    // Mapping from user address to list of owned token IDs
    mapping(address => uint256[]) private s_userTokens;

    constructor() ERC721("Chain Password Manager", "CPM") {}

    /**
     * Modifiers
     */
    // Modifier to check if the caller owns the token
    modifier onlyOwnerOf(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) {
            revert PasswordManager__NotTheOwner();
        }
        _;
    }

    // Modifier to check if the input is non-empty
    modifier nonEmptyInput(string memory input) {
        if (bytes(input).length == 0) {
            revert PasswordManager__EmptyInput();
        }
        _;
    }
    function getUserTokens() public view returns (uint256[] memory) {
        return s_userTokens[msg.sender];
    }
    function addPassword(
        string memory website,
        string memory encryptedUsername,
        string memory encryptedPassword,
        string memory message // Add the message as a parameter
    ) public {
        uint256 tokenId = uint256(keccak256(abi.encodePacked(s_userTokens[msg.sender].length, msg.sender, block.timestamp)));
        _safeMint(msg.sender, tokenId);
        s_passwordEntries[tokenId] = PasswordEntry({
            website: website,
            encryptedUsername: encryptedUsername,
            encryptedPassword: encryptedPassword,
            message: message, // Store the message
            tokenId: tokenId
        });
        s_userTokens[msg.sender].push(tokenId);
        emit PasswordAdded(tokenId, website);
    }
    
    // Function to update a password entry
    function updatePassword(
        uint256 tokenId,
        string memory encryptedUsername,
        string memory encryptedPassword,
        string memory message
    ) external onlyOwnerOf(tokenId) nonEmptyInput(encryptedUsername) nonEmptyInput(encryptedPassword) {
        // Update the encrypted username and password
        s_passwordEntries[tokenId].encryptedUsername = encryptedUsername;
        s_passwordEntries[tokenId].encryptedPassword = encryptedPassword;
        s_passwordEntries[tokenId].message = message;

        // Emit an event to log the update
        emit PasswordUpdated(tokenId, s_passwordEntries[tokenId].website);
    }

    // Function to delete a password entry (burn NFT)
    function deletePassword(uint256 tokenId) external onlyOwnerOf(tokenId) {
        // Burn the NFT
        _burn(tokenId);

        // Delete the password entry from the mapping
        delete s_passwordEntries[tokenId];

        // Remove the token from the user's list
        uint256[] storage userTokens = s_userTokens[msg.sender];
        for (uint256 i = 0; i < userTokens.length; i++) {
            if (userTokens[i] == tokenId) {
                // Swap with the last element and pop
                userTokens[i] = userTokens[userTokens.length - 1];
                userTokens.pop();
                break;
            }
        }

        // Emit an event to log the deletion
        emit PasswordDeleted(tokenId);
    }

    function getPasswords() external view returns (PasswordEntry[] memory) {
        // Fetch the list of token IDs owned by the caller
        uint256[] memory tokenIds = s_userTokens[msg.sender];
        PasswordEntry[] memory entries = new PasswordEntry[](tokenIds.length);

        // Fetch the password entries for each token ID
        for (uint256 i = 0; i < tokenIds.length; i++) {
            entries[i] = s_passwordEntries[tokenIds[i]];
        }

        return entries;
    }

    function getPasswordByTokenId(uint256 tokenId) external view onlyOwnerOf(tokenId) returns (PasswordEntry memory) {
        // Fetch the password entry for the token ID
        return s_passwordEntries[tokenId];
    }

    // Function to generate token URI (metadata)
    function tokenURI(uint256 tokenId) public view override onlyOwnerOf(tokenId) returns (string memory) {
        // Fetch the password entry for the token
        PasswordEntry memory entry = s_passwordEntries[tokenId];

        // Encode metadata as JSON
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"website": "', entry.website,
                        '", "encryptedUsername": "', entry.encryptedUsername,
                        '", "encryptedPassword": "', entry.encryptedPassword,
                        '"}'
                    )
                )
            )
        );

        // Return the Base64-encoded JSON as the token URI
        return string(abi.encodePacked("data:application/json;base64,", json));
    }
}
