// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract PasswordManager is ERC721 {
    error PasswordManager__NotTheOwner();
    error PasswordManager__TokenDoesNotExist();
    error PasswordManager__EmptyInput();

    event PasswordAdded(uint256 indexed tokenId, string website);
    event PasswordUpdated(uint256 indexed tokenId, string website);
    event PasswordDeleted(uint256 indexed tokenId);

    struct PasswordEntry {
        string website;
        string encryptedData;
    }

    mapping(uint256 => PasswordEntry) private s_passwords;
    mapping(address => mapping(uint256 => uint256)) private s_ownedTokenIndexes;
    mapping(address => uint256[]) private s_userTokens;

    constructor() ERC721("Chain Password Manager", "CPM") {}

    modifier onlyOwnerOf(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) {
            revert PasswordManager__NotTheOwner();
        }
        _;
    }

    modifier nonEmptyInput(string calldata input) {
        if (bytes(input).length == 0) {
            revert PasswordManager__EmptyInput();
        }
        _;
    }

    function getUserTokens() external view returns (uint256[] memory) {
        return s_userTokens[msg.sender];
    }

    function addPassword(
        string calldata website,
        string calldata encryptedData
    ) external nonEmptyInput(encryptedData) returns (uint256 tokenId) {
        tokenId = uint256(keccak256(abi.encodePacked(
            msg.sender,
            s_userTokens[msg.sender].length,
            block.timestamp
        )));

        _safeMint(msg.sender, tokenId);
        
        s_passwords[tokenId] = PasswordEntry({
            website: website,
            encryptedData: encryptedData
        });

        s_ownedTokenIndexes[msg.sender][tokenId] = s_userTokens[msg.sender].length;
        s_userTokens[msg.sender].push(tokenId);
        
        emit PasswordAdded(tokenId, website);
    }

    function updatePassword(
        uint256 tokenId,
        string calldata newEncryptedData
    ) external onlyOwnerOf(tokenId) nonEmptyInput(newEncryptedData) {
        s_passwords[tokenId].encryptedData = newEncryptedData;
        emit PasswordUpdated(tokenId, s_passwords[tokenId].website);
    }

    function deletePassword(uint256 tokenId) external onlyOwnerOf(tokenId) {
        address owner = msg.sender;
        
        // O(1) deletion from array
        uint256 lastIndex = s_userTokens[owner].length - 1;
        uint256 index = s_ownedTokenIndexes[owner][tokenId];
        
        if (index != lastIndex) {
            uint256 lastTokenId = s_userTokens[owner][lastIndex];
            s_userTokens[owner][index] = lastTokenId;
            s_ownedTokenIndexes[owner][lastTokenId] = index;
        }
        
        s_userTokens[owner].pop();
        delete s_ownedTokenIndexes[owner][tokenId];
        delete s_passwords[tokenId];
        _burn(tokenId);
        
        emit PasswordDeleted(tokenId);
    }

    function getPasswords() external view returns (PasswordEntry[] memory) {
        uint256[] memory tokenIds = s_userTokens[msg.sender];
        PasswordEntry[] memory entries = new PasswordEntry[](tokenIds.length);
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            entries[i] = s_passwords[tokenIds[i]];
        }
        return entries;
    }

    function getPassword(uint256 tokenId) external view onlyOwnerOf(tokenId) returns (PasswordEntry memory) {
        return s_passwords[tokenId];
    }

    function tokenURI(uint256 tokenId) public view override onlyOwnerOf(tokenId) returns (string memory) {
        PasswordEntry memory entry = s_passwords[tokenId];
        bytes memory json = abi.encodePacked(
            '{"website":"', entry.website,
            '","encryptedData":"', entry.encryptedData,
            '"}'
        );
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(json)));
    }
}
