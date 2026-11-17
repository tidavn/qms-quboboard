// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/QuboBoard.sol";

/// @notice Deploy QuboBoard to QMS Testnet.
/// @dev Usage: source .env && forge script script/Deploy.s.sol --rpc-url qms_testnet --broadcast
contract Deploy is Script {
    function run() external returns (QuboBoard) {
        // Never deploy to the wrong chain by accident: this script is only
        // for QMS Testnet (chain 19480).
        if (block.chainid != 19480) revert("wrong chain: expected QMS Testnet (19480)");
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        QuboBoard board = new QuboBoard();
        vm.stopBroadcast();
        console.log("QuboBoard deployed to:", address(board));
        return board;
    }
}
