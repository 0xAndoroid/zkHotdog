// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/ZkHotdog.sol";

contract ZkHotdogTest is Test {
    ZkHotdog public zkhotdog;

    address public owner;
    address public user1;
    address public user2;

    string public constant TEST_IMAGE_URL = "https://example.com/hotdog.jpg";
    uint256 public constant TEST_LENGTH = 25; // 25 cm

    // Mock data for ZK proof (currently not verified in the contract)
    bytes public mockProof = hex"1234";
    uint256[] public mockPublicSignals;

    function setUp() public {
        owner = address(1);
        user1 = address(2);
        user2 = address(3);

        vm.startPrank(owner);
        zkhotdog = new ZkHotdog(owner);
        vm.stopPrank();

        // Setup mock public signals
        mockPublicSignals = new uint256[](1);
        mockPublicSignals[0] = 123;
    }

    // Test minting functionality
    function testMint() public {
        vm.startPrank(user1);

        // Before minting
        assertEq(zkhotdog.balanceOf(user1), 0);

        // Mint a token
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockProof,
            mockPublicSignals
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
        zkhotdog.mint("", TEST_LENGTH, mockProof, mockPublicSignals);

        vm.stopPrank();
    }

    // Test multiple mints
    function testMultipleMints() public {
        vm.startPrank(user1);

        // Mint 3 tokens
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockProof,
            mockPublicSignals
        );
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH + 5,
            mockProof,
            mockPublicSignals
        );
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH + 10,
            mockProof,
            mockPublicSignals
        );

        // Check balances and ownership
        assertEq(zkhotdog.balanceOf(user1), 3);
        assertEq(zkhotdog.ownerOf(1), user1);
        assertEq(zkhotdog.ownerOf(2), user1);
        assertEq(zkhotdog.ownerOf(3), user1);

        vm.stopPrank();
    }

    // Test token verification
    function testVerifyToken() public {
        // Mint a token first
        vm.startPrank(user1);
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockProof,
            mockPublicSignals
        );
        vm.stopPrank();

        // Check initial verification status
        assertFalse(zkhotdog.isVerified(1));

        // Verify the token (owner only)
        vm.prank(owner);
        zkhotdog.verifyToken(1);

        // Check verification status after
        assertTrue(zkhotdog.isVerified(1));
    }

    // Test verification by non-owner (should revert)
    function testVerifyTokenNonOwner() public {
        // Mint a token first
        vm.startPrank(user1);
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockProof,
            mockPublicSignals
        );
        vm.stopPrank();

        // Try to verify as non-owner
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user2
            )
        );
        zkhotdog.verifyToken(1);

        // Status should remain unverified
        assertFalse(zkhotdog.isVerified(1));
    }

    // Test burn functionality
    function testBurn() public {
        // Mint a token first
        vm.startPrank(user1);
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockProof,
            mockPublicSignals
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
        zkhotdog.mint(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockProof,
            mockPublicSignals
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
}
