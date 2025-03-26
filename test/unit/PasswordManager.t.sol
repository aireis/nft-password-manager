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

    /**
     * Events
     */
    event PasswordAdded(uint256 indexed tokenId, string website);
    event PasswordUpdated(uint256 indexed tokenId, string website);
    event PasswordDeleted(uint256 indexed tokenId);

    /**
     * Setup
     */
    function setUp() public {
        deployer = new DeployPasswordManager();
        passwordManager = deployer.run();

        // Define test data
        testData = PasswordManager.PasswordEntry({
            website: "https://linkedin.com",
            encryptedData: "encryptedDataHere",
            createdAt: uint32(block.timestamp)
        });
    }

    /**
     * Helper Functions
     */
    function _addPasswordAndGetTokenId(address user, string memory website, string memory encryptedData) internal returns (uint256) {
        vm.recordLogs(); // Start recording logs to capture the emitted event
        vm.prank(user);
        passwordManager.addPassword(website, encryptedData);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        return uint256(logs[1].topics[1]); // Return the emitted tokenId
    }

    function _assertPasswordEntry(PasswordManager.PasswordEntry memory entry, string memory website, string memory encryptedData) view internal {
        assertEq(entry.website, website, "Website mismatch");
        assertEq(entry.encryptedData, encryptedData, "Encrypted data mismatch");
        assertEq(entry.createdAt, uint32(block.timestamp), "Timestamp mismatch");
    }

    function _assertTokenURI(uint256 tokenId, string memory website, string memory encryptedData) internal {
        // Encode metadata as JSON
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"website":"', website,
                        '","encryptedData":"', encryptedData,
                        '","createdAt":', uint256(uint32(block.timestamp)),
                        '}'
                    )
                )
            )
        );

        // Expected token URI
        string memory expectedTokenUri = string(abi.encodePacked("data:application/json;base64,", json));

        // Fetch actual token URI
        vm.prank(USER);
        string memory actualTokenUri = passwordManager.tokenURI(tokenId);

        // Assert equality
        assertEq(expectedTokenUri, actualTokenUri, "Token URI mismatch");
    }

    /**
     * Tests
     */
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
        assertEq(tokenIds.length, 0, "User should have no NFTs");
    }

    function testAddOnePassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        // Fetch the user's password entries
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory entries = passwordManager.getPasswords();

        // Assert that the user has exactly one password entry
        assertEq(entries.length, 1, "User should have exactly one password entry");

        // Assert that the added password entry matches the input data
        _assertPasswordEntry(entries[0], testData.website, testData.encryptedData);

        // Assert token URI
        _assertTokenURI(tokenId, testData.website, testData.encryptedData);
    }

    function testUpdatePassword_EmptyInput() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        // Attempt to update with empty data
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
        // Limit number of entries for performance reasons
        uint8 maxEntries = 20;
        if (numEntries == 0) numEntries = 1; // Ensure at least one entry
        if (numEntries > maxEntries) numEntries = maxEntries;

        for (uint8 i = 0; i < numEntries; i++) {
            // Generate pseudo-random test data
            string memory website = string(abi.encodePacked("https://site", Strings.toString(i), ".com"));
            string memory encryptedData = string(abi.encodePacked("encryptedData", Strings.toString(i)));

            // Add password
            _addPasswordAndGetTokenId(USER, website, encryptedData);
        }

        // Fetch stored passwords
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory storedEntries = passwordManager.getPasswords();

        // Verify all entries are stored correctly
        assertEq(storedEntries.length, numEntries, "Number of stored passwords mismatch");
    }

    function testOnlyOwnerCanUpdateAPassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        // Define the new encrypted data
        string memory newEncryptedData = "newEncryptedData";

        // Try to update the password as the owner (this should succeed)
        vm.prank(USER);
        passwordManager.updatePassword(tokenId, newEncryptedData);

        // Fetch the updated password entry
        vm.prank(USER);
        PasswordManager.PasswordEntry memory updatedEntry = passwordManager.getPassword(tokenId);

        // Assert that the password entry has been updated correctly
        assertEq(updatedEntry.encryptedData, newEncryptedData, "Data was not updated correctly");

        // Now try updating the password as a non-owner (should fail)
        address anotherUser = makeAddr("hacker");
        vm.prank(anotherUser);
        vm.expectRevert(PasswordManager.PasswordManager__NotTheOwner.selector);
        passwordManager.updatePassword(tokenId, "hackedData");
    }

    function testDeletePassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        // Simulate the user deleting the password
        vm.prank(USER);
        passwordManager.deletePassword(tokenId);

        // Assert that the user has no NFTs after deletion
        assertEq(passwordManager.balanceOf(USER), 0, "User should have no NFTs after deletion");

        // Fetch the user's password entries after deletion
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory updatedEntries = passwordManager.getPasswords();

        // Assert that the user has no password entries after deletion
        assertEq(updatedEntries.length, 0, "User should have no password entries after deletion");

        // Assert that the token ID is removed from s_userTokens
        vm.prank(USER);
        uint256[] memory userTokens = passwordManager.getUserTokens();
        assertEq(userTokens.length, 0, "User should have no token IDs after deletion");
    }

    function testTokenURI_NonExistentToken() public {
        uint256 nonExistentTokenId = 123; // Token not minted
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
        uint256 nonExistentTokenId = 123; // Token not minted
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                nonExistentTokenId
            )
        );
        passwordManager.getPassword(nonExistentTokenId);
    }

    function testDeletePassword_NonExistentToken() public {
        uint256 nonExistentTokenId = 123; // Token not minted
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                nonExistentTokenId
            )
        );
        passwordManager.deletePassword(nonExistentTokenId);
    }

    function testUpdatePassword_NonExistentToken() public {
        uint256 nonExistentTokenId = 123; // Token not minted
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

        // Define new data
        string memory newEncryptedData = "newEncryptedData";

        // Expect the PasswordUpdated event
        vm.expectEmit(true, true, true, true);
        emit PasswordUpdated(tokenId, testData.website);

        // Update the password
        vm.prank(USER);
        passwordManager.updatePassword(tokenId, newEncryptedData);
    }

    function testDeletePassword_EventEmitted() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        // Expect the PasswordDeleted event
        vm.expectEmit(true, true, true, true);
        emit PasswordDeleted(tokenId);

        // Delete the password
        vm.prank(USER);
        passwordManager.deletePassword(tokenId);
    }

    function testOnlyOwnerOf_AllowsOwner() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        // Simulate the owner calling a function with the modifier
        vm.prank(USER);
        passwordManager.getPassword(tokenId);
    }

    function testOnlyOwnerOf_RevertsIfNotOwner() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData.website, testData.encryptedData);

        // Simulate a different user calling a function with the modifier
        address anotherUser = makeAddr("hacker");
        vm.prank(anotherUser);

        // Expect revert with PasswordManager__NotTheOwner
        vm.expectRevert(PasswordManager.PasswordManager__NotTheOwner.selector);
        passwordManager.getPassword(tokenId);
    }
}
