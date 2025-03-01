// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/ZkHotdog.sol";
import "../contracts/MockZkVerify.sol";
import "../contracts/IZkHotdogServiceManager.sol";

// Mock Service Manager for testing automatic task creation
contract MockServiceManager {
    uint256 private lastTokenId;
    string private lastImageUrl;
    uint32 private constant MOCK_TASK_INDEX = 123;

    function createNewTask(uint256 tokenId, string memory imageUrl) external returns (IZkHotdogServiceManager.Task memory) {
        lastTokenId = tokenId;
        lastImageUrl = imageUrl;

        // Return a mock task
        return IZkHotdogServiceManager.Task({
            tokenId: tokenId,
            imageUrl: imageUrl,
            taskCreatedBlock: uint32(block.number)
        });
    }

    function latestTaskNum() external pure returns (uint32) {
        return MOCK_TASK_INDEX + 1; // So that latestTaskNum - 1 = MOCK_TASK_INDEX
    }

    function getLastTaskCreated() external view returns (uint256, string memory) {
        return (lastTokenId, lastImageUrl);
    }
    
    function mockTaskIndex() external pure returns (uint32) {
        return MOCK_TASK_INDEX;
    }
}

contract ZkHotdogTest is Test {
    ZkHotdog public zkhotdog;
    MockZkVerify public mockZkVerify;

    address public owner;
    address public user1;
    address public user2;

    string public constant TEST_IMAGE_URL = "https://example.com/hotdog.jpg";
    uint256 public constant TEST_LENGTH = 25; // 25 cm

    // Mock data for ZK proof (currently not verified in the contract)
    bytes public mockProof = hex"1234";
    uint256[] public mockPublicSignals;
    
    // Mock data for attestation verification
    uint256 public mockAttestationId = 12345;
    bytes32[] public mockMerklePath;
    uint256 public mockLeafCount = 10;
    uint256 public mockIndex = 3;
    bytes32 public mockVkey = bytes32(uint256(123456789));

    function setUp() public {
        owner = address(1);
        user1 = address(2);
        user2 = address(3);

        // Create mock merkle path
        mockMerklePath = new bytes32[](3);
        mockMerklePath[0] = bytes32(uint256(111));
        mockMerklePath[1] = bytes32(uint256(222));
        mockMerklePath[2] = bytes32(uint256(333));

        vm.startPrank(owner);
        // Create mock zkVerify contract
        mockZkVerify = new MockZkVerify();
        
        // Create ZkHotdog contract with mock zkVerify
        zkhotdog = new ZkHotdog(address(mockZkVerify), mockVkey);
        vm.stopPrank();

        // Setup mock public signals
        mockPublicSignals = new uint256[](1);
        mockPublicSignals[0] = 123;
    }

    // Test attestation-based minting
    function testMintWithAttestation() public {
        vm.startPrank(user1);

        // Before minting
        assertEq(zkhotdog.balanceOf(user1), 0);

        // Mint a token with attestation
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );

        // After minting
        assertEq(zkhotdog.balanceOf(user1), 1);
        assertEq(zkhotdog.ownerOf(1), user1);
        assertEq(zkhotdog.tokenOfOwnerByIndex(user1, 0), 1);

        vm.stopPrank();
    }

    // Test minting with empty image URL (should revert)
    function testMintWithEmptyImageUrl() public {
        vm.startPrank(user1);

        // Try to mint with empty image URL
        vm.expectRevert("Image URL cannot be empty");
        zkhotdog.mintWithAttestation("", TEST_LENGTH, mockAttestationId, mockMerklePath, mockLeafCount, mockIndex);

        vm.stopPrank();
    }

    // Test multiple mints
    function testMultipleMints() public {
        vm.startPrank(user1);

        // Mint 3 tokens
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH + 5,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH + 10,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );

        // Check balances and ownership
        assertEq(zkhotdog.balanceOf(user1), 3);
        assertEq(zkhotdog.ownerOf(1), user1);
        assertEq(zkhotdog.ownerOf(2), user1);
        assertEq(zkhotdog.ownerOf(3), user1);

        vm.stopPrank();
    }

    // Test token verification
    function testTokenIsNotVerifiedAfterAttestation() public {
        // Mint a token with attestation
        vm.startPrank(user1);
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        vm.stopPrank();

        // Token should NOT be verified yet - verification happens through EigenLayer
        assertFalse(zkhotdog.isVerified(1));
    }

    // Test manual verification works
    function testManualVerification() public {
        // Mint a token with attestation (not verified yet)
        vm.startPrank(user1);
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        vm.stopPrank();
        
        // Mint another token that we'll verify manually
        vm.startPrank(user1);
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH + 5,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        vm.stopPrank();

        // Verify the first token manually
        vm.prank(owner);
        zkhotdog.verifyToken(1);
        
        // Check that it's now verified
        assertTrue(zkhotdog.isVerified(1));
        
        // Check that the second token is still unverified
        assertFalse(zkhotdog.isVerified(2));
        
        // Verify the second token manually
        vm.prank(owner);
        zkhotdog.verifyToken(2);
        
        // Now the second should be verified
        assertTrue(zkhotdog.isVerified(2));
    }
    
    // Test verification by non-owner (should revert)
    function testVerifyTokenNonOwner() public {
        // Mint a token with attestation
        vm.startPrank(user1);
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        vm.stopPrank();
        
        // The token should not be verified automatically
        assertFalse(zkhotdog.isVerified(1));

        // Try to verify as non-owner (user2)
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        zkhotdog.verifyToken(1);
        
        // Token should still be unverified
        assertFalse(zkhotdog.isVerified(1));
        
        // Now verify using owner
        vm.prank(owner);
        zkhotdog.verifyToken(1);
        
        // Now it should be verified
        assertTrue(zkhotdog.isVerified(1));
    }

    // Test burn functionality
    function testBurn() public {
        // Mint a token first
        vm.startPrank(user1);
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        vm.stopPrank();

        // Verify token exists
        assertEq(zkhotdog.balanceOf(user1), 1);
        assertEq(zkhotdog.ownerOf(1), user1);
        
        // Manually verify the token
        vm.prank(owner);
        zkhotdog.verifyToken(1);
        assertTrue(zkhotdog.isVerified(1));

        // Any user can burn tokens (even non-owners)
        vm.prank(user2);
        zkhotdog.burn(1);

        // Token should no longer exist
        assertEq(zkhotdog.balanceOf(user1), 0);

        // Checking ownerOf should revert with error
        vm.expectRevert("ERC721: invalid token ID");
        zkhotdog.ownerOf(1);
    }

    // Test soulbound property (no transfers)
    function testNoTransfers() public {
        // Mint a token first
        vm.startPrank(user1);
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );

        // Try to transfer (should revert with custom error)
        vm.expectRevert(abi.encodeWithSignature("TokenIsNontransferable()"));
        zkhotdog.transferFrom(user1, user2, 1);

        vm.stopPrank();
    }

    // Test non-existent token operations
    function testNonExistentToken() public {
        // Check token that doesn't exist
        vm.expectRevert("ERC721: invalid token ID");
        zkhotdog.ownerOf(999);

        vm.expectRevert("Token does not exist");
        zkhotdog.tokenURI(999);

        vm.expectRevert("Token does not exist");
        zkhotdog.isVerified(999);

        vm.prank(owner);
        vm.expectRevert("Token does not exist");
        zkhotdog.verifyToken(999);
    }
    
    // Test attestation data is handled correctly
    function testAttestationVerification() public {
        vm.startPrank(user1);
        
        // Mint token with attestation
        zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        
        vm.stopPrank();
        
        // The token should NOT be verified automatically
        assertFalse(zkhotdog.isVerified(1));
        
        // Now verify it manually
        vm.prank(owner);
        zkhotdog.verifyToken(1);
        
        // Now it should be verified
        assertTrue(zkhotdog.isVerified(1));
        
        // Check that attestation data was handled correctly by viewing tokenURI
        string memory uri = zkhotdog.tokenURI(1);
        
        // The URI contains the verified status, but we can't directly check the string contents
        // in this test. In a real system, we'd parse the Base64 data and check the JSON.
        assertGt(bytes(uri).length, 0);
    }
    
    // Test service manager integration
    function testServiceManagerIntegration() public {
        // Set up a mock service manager address
        address mockServiceManager = address(0x123);
        
        // Set the service manager
        vm.prank(owner);
        zkhotdog.setServiceManager(mockServiceManager);
        
        // Check that service manager was correctly set
        assertEq(zkhotdog.serviceManager(), mockServiceManager);

        // Mock the createNewTask function call 
        // that will be called during minting
        vm.mockCall(
            mockServiceManager,
            abi.encodeWithSelector(
                IZkHotdogServiceManager.createNewTask.selector,
                1, // expected tokenId
                TEST_IMAGE_URL
            ),
            abi.encode(IZkHotdogServiceManager.Task({
                tokenId: 1,
                imageUrl: TEST_IMAGE_URL,
                taskCreatedBlock: uint32(block.number)
            }))
        );
        
        // Mock the latestTaskNum call that will be used to set the task index
        vm.mockCall(
            mockServiceManager,
            abi.encodeWithSelector(IZkHotdogServiceManager.latestTaskNum.selector),
            abi.encode(uint32(42)) // fake task number
        );
        
        // Mint a token with service manager set - should automatically create a task
        vm.startPrank(user1);
        uint256 tokenId = zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        vm.stopPrank();
        
        // Check that the token was minted
        assertEq(zkhotdog.ownerOf(tokenId), user1);
        
        // Verify the task index was set in the metadata
        // taskIndex should be latestTaskNum - 1 = 41
        assertEq(zkhotdog.getTaskIndex(tokenId), 41);
        
        // Initially the token should not be verified
        assertFalse(zkhotdog.isVerified(tokenId));
        
        // Verify a token using the service manager address
        vm.prank(mockServiceManager);
        zkhotdog.verifyToken(tokenId);
        
        // Check that it's now verified
        assertTrue(zkhotdog.isVerified(tokenId));
    }
    
    // Test minting with automatic task creation
    function testMintWithAutomaticTaskCreation() public {
        // Create a mock ZkHotdogServiceManager
        MockServiceManager mockSM = new MockServiceManager();
        
        // Set the service manager 
        vm.prank(owner);
        zkhotdog.setServiceManager(address(mockSM));
        
        // Mint an NFT - this should automatically create a task
        vm.startPrank(user1);
        uint256 tokenId = zkhotdog.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        vm.stopPrank();
        
        // Verify the mock service manager recorded the correct data
        (uint256 recordedTokenId, string memory recordedImageUrl) = mockSM.getLastTaskCreated();
        
        // Check the token ID and image URL match what was sent
        assertEq(recordedTokenId, tokenId);
        assertEq(recordedImageUrl, TEST_IMAGE_URL);
        
        // Check the token's task index was updated
        assertEq(zkhotdog.getTaskIndex(tokenId), mockSM.mockTaskIndex());
    }
}
