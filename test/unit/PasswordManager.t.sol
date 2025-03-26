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
            tokenId: 0, // Will be set dynamically
            website: "https://linkedin.com",
            encryptedUsername: "me",
            encryptedPassword: "secret!",
            message: "test-message"
        });
    }

    /**
     * Helper Functions
     */
    function _addPasswordAndGetTokenId(address user, PasswordManager.PasswordEntry memory entry) internal returns (uint256) {
        vm.recordLogs(); // Start recording logs to capture the emitted event
        vm.prank(user);
        passwordManager.addPassword(entry.website, entry.encryptedUsername, entry.encryptedPassword, entry.message);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        return uint256(logs[1].topics[1]); // Return the emitted tokenId
    }

    function _assertPasswordEntry(PasswordManager.PasswordEntry memory entry, PasswordManager.PasswordEntry memory expected) pure internal {
        assertEq(entry.tokenId, expected.tokenId, "Token ID mismatch");
        assertEq(entry.website, expected.website, "Website mismatch");
        assertEq(entry.encryptedUsername, expected.encryptedUsername, "Encrypted username mismatch");
        assertEq(entry.encryptedPassword, expected.encryptedPassword, "Encrypted password mismatch");
        assertEq(entry.message, expected.message, "Message mismatch");
    }

    function _assertTokenURI(uint256 tokenId, PasswordManager.PasswordEntry memory entry) internal {
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
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

        // Update testData with the tokenId
        testData.tokenId = tokenId;

        // Fetch the user's password entries
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory entries = passwordManager.getPasswords();

        // Assert that the user has exactly one password entry
        assertEq(entries.length, 1, "User should have exactly one password entry");

        // Assert that the added password entry matches the input data
        _assertPasswordEntry(entries[0], testData);

        // Assert token URI
        _assertTokenURI(tokenId, testData);
    }

    function testUpdatePassword_EmptyInput() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

        // Attempt to update with empty username
        vm.prank(USER);
        vm.expectRevert(PasswordManager.PasswordManager__EmptyInput.selector);
        passwordManager.updatePassword(tokenId, "", "newPassword", "newMessage");

        // Attempt to update with empty password
        vm.prank(USER);
        vm.expectRevert(PasswordManager.PasswordManager__EmptyInput.selector);
        passwordManager.updatePassword(tokenId, "newUsername", "", "newMessage");
    }

    function testGetUserEmptyTokens() public {
        address newrUser = makeAddr("newUser");
        // Attempt to update with empty username
        vm.prank(newrUser);
        passwordManager.getUserTokens();
    }

    function testFuzz_AddMultiplePasswords(uint8 numEntries) public {
        // Limit number of entries for performance reasons
        uint8 maxEntries = 20;
        if (numEntries == 0) numEntries = 1; // Ensure at least one entry
        if (numEntries > maxEntries) numEntries = maxEntries;

        PasswordManager.PasswordEntry[] memory expectedEntries = new PasswordManager.PasswordEntry[](numEntries);

        for (uint8 i = 0; i < numEntries; i++) {
            // Generate pseudo-random test data
            string memory website = string(abi.encodePacked("https://site", Strings.toString(i), ".com"));
            string memory username = string(abi.encodePacked("user", Strings.toString(i)));
            string memory password = string(abi.encodePacked("pass", Strings.toString(i)));
            string memory message = "test-message";

            expectedEntries[i] = PasswordManager.PasswordEntry({
                tokenId: 0, // Will be set dynamically
                website: website,
                encryptedUsername: username,
                encryptedPassword: password,
                message: message
            });

            // Add password and get tokenId
            uint256 tokenId = _addPasswordAndGetTokenId(USER, expectedEntries[i]);
            expectedEntries[i].tokenId = tokenId;
        }

        // Fetch stored passwords
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory storedEntries = passwordManager.getPasswords();

        // Verify all entries are stored correctly
        assertEq(storedEntries.length, numEntries, "Number of stored passwords mismatch");

        for (uint8 i = 0; i < numEntries; i++) {
            _assertPasswordEntry(storedEntries[i], expectedEntries[i]);
        }
    }

    function testOnlyOwnerCanUpdateAPassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

        // Define the new password data
        string memory newEncryptedUsername = "newUser";
        string memory newEncryptedPassword = "newSecret!";
        string memory message = "message";

        // Try to update the password as the owner (this should succeed)
        vm.prank(USER);
        passwordManager.updatePassword(tokenId, newEncryptedUsername, newEncryptedPassword, message);

        // Fetch the updated password entry
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory entries = passwordManager.getPasswords();
        PasswordManager.PasswordEntry memory updatedEntry = entries[0];

        // Assert that the password entry has been updated correctly
        assertEq(updatedEntry.encryptedUsername, newEncryptedUsername, "Username was not updated correctly");
        assertEq(updatedEntry.encryptedPassword, newEncryptedPassword, "Password was not updated correctly");
        assertEq(updatedEntry.message, message, "Message was not updated correctly");

        // Now try updating the password as a non-owner (should fail)
        address anotherUser = makeAddr("hacker");
        vm.prank(anotherUser);
        vm.expectRevert(PasswordManager.PasswordManager__NotTheOwner.selector);
        passwordManager.updatePassword(tokenId, "hackedUser", "hackedPassword", "hackedMessage");
    }

    function testDeletePassword() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

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

    function testGetPasswordByTokenId_NonExistentToken() public {
        uint256 nonExistentTokenId = 123; // Token not minted
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Errors.ERC721NonexistentToken.selector,
                nonExistentTokenId
            )
        );
        passwordManager.getPasswordByTokenId(nonExistentTokenId);
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
        passwordManager.updatePassword(nonExistentTokenId, "newUsername", "newPassword", "newMessage");
    }

    function testGetPasswords_NoTokens() public {
        vm.prank(USER);
        PasswordManager.PasswordEntry[] memory entries = passwordManager.getPasswords();
        assertEq(entries.length, 0, "User should have no password entries");
    }

    function testUpdatePassword_EventEmitted() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

        // Define new data
        string memory newUsername = "newUser";
        string memory newPassword = "newPassword";
        string memory newMessage = "newMessage";

        // Expect the PasswordUpdated event
        vm.expectEmit(true, true, true, true);
        emit PasswordUpdated(tokenId, testData.website);

        // Update the password
        vm.prank(USER);
        passwordManager.updatePassword(tokenId, newUsername, newPassword, newMessage);
    }

    function testDeletePassword_EventEmitted() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

        // Expect the PasswordDeleted event
        vm.expectEmit(true, true, true, true);
        emit PasswordDeleted(tokenId);

        // Delete the password
        vm.prank(USER);
        passwordManager.deletePassword(tokenId);
    }

    function testOnlyOwnerOf_AllowsOwner() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

        // Simulate the owner calling a function with the modifier
        vm.prank(USER);
        passwordManager.getPasswordByTokenId(tokenId);
    }

    function testOnlyOwnerOf_RevertsIfNotOwner() public {
        uint256 tokenId = _addPasswordAndGetTokenId(USER, testData);

        // Simulate a different user calling a function with the modifier
        address anotherUser = makeAddr("hacker");
        vm.prank(anotherUser);

        // Expect revert with PasswordManager__NotTheOwner
        vm.expectRevert(PasswordManager.PasswordManager__NotTheOwner.selector);
        passwordManager.getPasswordByTokenId(tokenId);
    }
}
