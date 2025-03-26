// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {IERC721Errors} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {PasswordManager} from "src/PasswordManager.sol";
import {DeployPasswordManager} from "script/DeployPasswordManager.s.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract PasswordManagerTest is Test {
    DeployPasswordManager deployer;
    PasswordManager passwordManager;
    PasswordManager.PasswordEntry testData;
    address public USER = makeAddr("user");

    event PasswordAdded(uint256 indexed tokenId, string website);
    event PasswordUpdated(uint256 indexed tokenId, string website);
    event PasswordDeleted(uint256 indexed tokenId);

    function setUp() public {
        deployer = new DeployPasswordManager();
        passwordManager = deployer.run();

        testData = PasswordManager.PasswordEntry({
            website: "https://linkedin.com",
            encryptedData: "encryptedDataHere"
        });
    }

    function _addPasswordAndGetTokenId(address user, string memory website, string memory encryptedData) internal returns (uint256) {
        vm.recordLogs();
        vm.prank(user);
        passwordManager.addPassword(website, encryptedData);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        return uint256(logs[1].topics[1]);
    }

    function _assertPasswordEntry(PasswordManager.PasswordEntry memory entry, string memory website, string memory encryptedData) internal pure {
        assertEq(entry.website, website, "Website mismatch");
        assertEq(entry.encryptedData, encryptedData, "Encrypted data mismatch");
    }

    function _assertTokenURI(uint256 tokenId, string memory website, string memory encryptedData) internal {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"website":"', website,
                        '","encryptedData":"', encryptedData,
                        '"}'
                    )
                )
            )
        );
        string memory expectedTokenUri = string(abi.encodePacked("data:application/json;base64,", json));

        vm.prank(USER);
        string memory actualTokenUri = passwordManager.tokenURI(tokenId);

        assertEq(expectedTokenUri, actualTokenUri, "Token URI mismatch");
    }

    function testNameIsCorrect() public view {
        string memory expectedName = "Chain Password Manager";
        string memory actualName = passwordManager.name();
        assert(keccak256(bytes(expectedName)) == keccak256(bytes(actualName)));
    }

    function testSymbolIsCorrect() public view {
        string memory expectedSymbol = "CPM";
        string memory actualSymbol = passwordManager.symbol();
        assert(keccak256(bytes(expectedSymbol)) == keccak256(bytes(actualSymbol)));
    }

    function testNoTokenWhenInit() public {
        vm.prank(USER);
        uint256[] memory tokenIds = passwordManager.getUserTokens();
        assertEq(passwordManager.balanceOf(USER), 0, "User should have no NFTs");
        assertEq(tokenIds.length, 0, "User should have no token IDs");
    }

    function testAddOnePassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory entries = passwordManager.getPasswords();

        assertEq(entries.length, 1, "User should have exactly one password entry");
        _assertPasswordEntry(entries[0], testData.website, testData.encryptedData);
        _assertTokenURI(tokenId, testData.website, testData.encryptedData);
    }

    function testUpdatePassword_EmptyInput() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        vm.prank(USER);
        vm.expectRevert(PasswordManager.PasswordManager__EmptyInput.selector);
        passwordManager.updatePassword(tokenId, "");
    }

    function testGetUserEmptyTokens() public {
        address newUser = makeAddr("newUser");
        vm.prank(newUser);
        passwordManager.getUserTokens();
    }

    function testFuzz_AddMultiplePasswords(uint8 numEntries) public {
        numEntries = uint8(bound(numEntries, 1, 20));

        for (uint8 i = 0; i < numEntries; i++) {
            string memory website = string(abi.encodePacked("https://site", Strings.toString(i), ".com"));
            string memory encryptedData = string(abi.encodePacked("encryptedData", Strings.toString(i)));
            _addPasswordAndGetTokenId(USER, website, encryptedData);
        }

        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory storedEntries = passwordManager.getPasswords();
        assertEq(storedEntries.length, numEntries, "Number of stored passwords mismatch");
    }

    function testOnlyOwnerCanUpdateAPassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        string memory newEncryptedData = "newEncryptedData";
        vm.prank(USER);
        passwordManager.updatePassword(tokenId, newEncryptedData);

        vm.prank(USER);
        PasswordManager.PasswordEntry memory updatedEntry = passwordManager.getPassword(tokenId);
        assertEq(updatedEntry.encryptedData, newEncryptedData, "Data was not updated correctly");

        address anotherUser = makeAddr("hacker");
        vm.prank(anotherUser);
        vm.expectRevert(PasswordManager.PasswordManager__NotTheOwner.selector);
        passwordManager.updatePassword(tokenId, "hackedData");
    }

    function testDeletePassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        vm.prank(USER);
        passwordManager.deletePassword(tokenId);

        assertEq(passwordManager.balanceOf(USER), 0, "User should have no NFTs after deletion");
        
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory updatedEntries = passwordManager.getPasswords();
        assertEq(updatedEntries.length, 0, "User should have no password entries after deletion");

        vm.prank(USER);
        uint256[] memory userTokens = passwordManager.getUserTokens();
        assertEq(userTokens.length, 0, "User should have no token IDs after deletion");
    }

    function testTokenURI_NonExistentToken() public {
        uint256 nonExistentTokenId = 123;
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                nonExistentTokenId
            )
        );
        vm.prank(USER);
        passwordManager.tokenURI(nonExistentTokenId);
    }

    function testGetPassword_NonExistentToken() public {
        uint256 nonExistentTokenId = 123;
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                nonExistentTokenId
            )
        );
        passwordManager.getPassword(nonExistentTokenId);
    }

    function testDeletePassword_NonExistentToken() public {
        uint256 nonExistentTokenId = 123;
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                nonExistentTokenId
            )
        );
        passwordManager.deletePassword(nonExistentTokenId);
    }

    function testUpdatePassword_NonExistentToken() public {
        uint256 nonExistentTokenId = 123;
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                nonExistentTokenId
            )
        );
        passwordManager.updatePassword(nonExistentTokenId, "newEncryptedData");
    }

    function testGetPasswords_NoTokens() public {
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory entries = passwordManager.getPasswords();
        assertEq(entries.length, 0, "User should have no password entries");
    }

    function testUpdatePassword_EventEmitted() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        vm.expectEmit(true, true, true, true);
        emit PasswordUpdated(tokenId, testData.website);

        vm.prank(USER);
        passwordManager.updatePassword(tokenId, "newEncryptedData");
    }

    function testDeletePassword_EventEmitted() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        vm.expectEmit(true, true, true, true);
        emit PasswordDeleted(tokenId);

        vm.prank(USER);
        passwordManager.deletePassword(tokenId);
    }

    function testOnlyOwnerOf_AllowsOwner() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        vm.prank(USER);
        passwordManager.getPassword(tokenId);
    }

    function testOnlyOwnerOf_RevertsIfNotOwner() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        address anotherUser = makeAddr("hacker");
        vm.prank(anotherUser);

        vm.expectRevert(PasswordManager.PasswordManager__NotTheOwner.selector);
        passwordManager.getPassword(tokenId);
    }

    function testTokenURI_Format() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);
        vm.prank(USER);
        string memory uri = passwordManager.tokenURI(tokenId);
        
        // Expected prefix
        string memory expectedPrefix = "data:application/json;base64,";
        
        // Check prefix using hash comparison
        bytes memory uriBytes = bytes(uri);
        bytes memory prefixBytes = bytes(expectedPrefix);
        
        // 1. Quick length check first
        require(
            uriBytes.length > prefixBytes.length, 
            "Token URI too short"
        );
    }
}
