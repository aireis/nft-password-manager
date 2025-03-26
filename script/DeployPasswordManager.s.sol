// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {PasswordManager} from "../src/PasswordManager.sol";

contract DeployPasswordManager is Script {
    function run() external returns(PasswordManager) {
        vm.startBroadcast();
        PasswordManager passwordManager = new PasswordManager();
        vm.stopBroadcast();
        return passwordManager;
    }
}
