// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/ZkHotdog.sol";
import "../contracts/MockZkVerify.sol";

/**
 * @notice Deploy script for ZkHotdog contract
 * @dev Inherits ScaffoldETHDeploy which:
 *      - Includes forge-std/Script.sol for deployment
 *      - Includes ScaffoldEthDeployerRunner modifier
 *      - Provides `deployer` variable
 * Example:
 * yarn deploy --file DeployYourContract.s.sol  # local anvil chain
 * yarn deploy --file DeployYourContract.s.sol --network optimism # live network (requires keystore)
 */
contract DeployZkHotdog is ScaffoldETHDeploy {
    /**
     * @dev Deployer setup based on `ETH_KEYSTORE_ACCOUNT` in `.env`:
     *      - "scaffold-eth-default": Uses Anvil's account #9 (0xa0Ee7A142d267C1f36714E4a8F75612F20a79720), no password prompt
     *      - "scaffold-eth-custom": requires password used while creating keystore
     *
     * Note: Must use ScaffoldEthDeployerRunner modifier to:
     *      - Setup correct `deployer` account and fund it
     *      - Export contract addresses & ABIs to `nextjs` packages
     */
    function run() external ScaffoldEthDeployerRunner {
        // For development, we'll deploy a mock zkVerify contract
        MockZkVerify mockZkVerify = new MockZkVerify();
        
        // Use a test vkey
        bytes32 vkey = bytes32(uint256(123456789));
        
        // Deploy the zkHotdog contract with mock zkVerify
        ZkHotdog zkHotdog = new ZkHotdog(deployer, address(mockZkVerify), vkey);
        
        console.log("Deployed MockZkVerify at:", address(mockZkVerify));
        console.log("Deployed ZkHotdog at:", address(zkHotdog));
    }
}
