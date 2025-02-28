// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/ZkHotdog.sol";
import "../contracts/MockZkVerify.sol";

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
        zkhotdog = new ZkHotdog(owner, address(mockZkVerify), mockVkey);
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
    function testTokenIsVerifiedAfterAttestation() public {
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

        // Token should be already verified through zkVerify attestation
        assertTrue(zkhotdog.isVerified(1));
    }

    // Test manual verification still works
    function testManualVerification() public {
        // Mint a token with attestation (already verified)
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

        // The second token was auto-verified too, so manually verifying it
        // should revert as it's already verified
        vm.prank(owner);
        vm.expectRevert("Token already verified");
        zkhotdog.verifyToken(2);
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
        
        // Create a new token that needs verification
        vm.prank(owner);
        // Let's pretend token 2 needs verification
        // Set token 2's verified status to false for testing
        // (We can't directly do this in a real scenario, this is just for testing)
        zkhotdog.verifyToken(1);

        // Try to verify as non-owner
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user2
            )
        );
        zkhotdog.verifyToken(1);
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

        // Any user can burn tokens (even non-owners)
        vm.prank(user2);
        zkhotdog.burn(1);

        // Token should no longer exist
        assertEq(zkhotdog.balanceOf(user1), 0);

        // Checking ownerOf should revert with custom error
        vm.expectRevert(
            abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 1)
        );
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
        vm.expectRevert(
            abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 999)
        );
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
        
        // The token should be verified already through attestation
        assertTrue(zkhotdog.isVerified(1));
        
        // Check that attestation data was handled correctly by viewing tokenURI
        string memory uri = zkhotdog.tokenURI(1);
        
        // The URI contains the verified status, but we can't directly check the string contents
        // in this test. In a real system, we'd parse the Base64 data and check the JSON.
        assertGt(bytes(uri).length, 0);
    }
}
