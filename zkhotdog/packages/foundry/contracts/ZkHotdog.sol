// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title zkHotdog NFT
 * @dev ERC721 contract for zkHotdog project with Groth16 proof verification
 */
contract ZkHotdog is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // Struct to store metadata for each token
    struct TokenMetadata {
        string imageUrl;
        uint256 lengthInCm;
        uint256 mintedAt;
        bool verified;
    }

    // Mapping from token ID to token metadata
    mapping(uint256 => TokenMetadata) private _tokenMetadata;

    // Counter for token IDs
    uint256 private _nextTokenId;

    // Event emitted when a new token is minted
    event HotdogMinted(
        address indexed to,
        uint256 indexed tokenId,
        string imageUrl,
        uint256 lengthInCm
    );

    // Event emitted when a token is burned
    event HotdogBurned(
        address indexed burner,
        address indexed owner,
        uint256 indexed tokenId
    );

    // Event emitted when a token is verified by the owner
    event HotdogVerified(uint256 indexed tokenId, address indexed verifier);

    error TokenIsNontransferable();

    /**
     * @dev Constructor initializes the contract with a name and symbol
     */
    constructor(address owner) ERC721("zkHotdog", "HOTDOG") Ownable(owner) {
        _nextTokenId = 1;
    }

    /**
     * @dev Mint a new token
     * @param imageUrl URL pointing to the image of the hotdog
     * @param lengthInCm Length of the hotdog in centimeters
     * @param proof Groth16 proof data
     * @param publicSignals Public inputs for the proof verification
     */
    function mint(
        string memory imageUrl,
        uint256 lengthInCm,
        bytes memory proof,
        uint256[] memory publicSignals
    ) public {
        // TODO: Verify Groth16 proof
        // verifyProof(proof, publicSignals);

        // For now, simply check that image URL is not empty
        require(bytes(imageUrl).length > 0, "Image URL cannot be empty");

        // Get the current token ID and increment for next mint
        uint256 tokenId = _nextTokenId++;

        // Mint the token to the caller
        _safeMint(msg.sender, tokenId);

        // Store the metadata
        _tokenMetadata[tokenId] = TokenMetadata({
            imageUrl: imageUrl,
            lengthInCm: lengthInCm,
            mintedAt: block.timestamp,
            verified: false
        });

        // Emit event
        emit HotdogMinted(msg.sender, tokenId, imageUrl, lengthInCm);
    }

    /**
     * @dev Get token URI for a specific token ID
     * @param tokenId Token ID to get URI for
     * @return Token URI as a string
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");

        TokenMetadata memory metadata = _tokenMetadata[tokenId];

        // Create JSON metadata
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "zkHotdog #',
                        tokenId.toString(),
                        '", "description": "A verified hotdog with ZK proof of length.", ',
                        '"image": "',
                        metadata.imageUrl,
                        '", "attributes": [',
                        '{"trait_type": "Length (cm)", "value": "',
                        metadata.lengthInCm.toString(),
                        '"},',
                        '{"trait_type": "Minted At", "value": "',
                        metadata.mintedAt.toString(),
                        '"},',
                        '{"trait_type": "Verified", "value": "',
                        metadata.verified ? "Yes" : "No",
                        '"}',
                        "]}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /**
     * @dev Check if a token exists
     * @param tokenId Token ID to check
     * @return true if the token exists, false otherwise
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Placeholder for Groth16 proof verification
     * @param proof Groth16 proof data
     * @param publicSignals Public inputs for the proof verification
     * @return true if the proof is valid, false otherwise
     */
    function verifyProof(
        bytes memory proof,
        uint256[] memory publicSignals
    ) internal pure returns (bool) {
        // TODO: Implement Groth16 proof verification
        // This would integrate with the zkSNARK verification library

        // For now, just return true
        return true;
    }

    /**
     * @dev Returns the number of tokens owned by an address
     * @param owner Address to check
     * @return The number of tokens owned by the address
     */
    function balanceOf(
        address owner
    ) public view override(ERC721, IERC721) returns (uint256) {
        return super.balanceOf(owner);
    }

    /**
     * @dev Returns a token ID owned by an address at a given index
     * @param owner Address to check
     * @param index Index of the token
     * @return Token ID
     */
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) public view override returns (uint256) {
        return super.tokenOfOwnerByIndex(owner, index);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            revert TokenIsNontransferable();
        }
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Burns a token - can be called by anyone
     * @param tokenId Token ID to burn
     */
    function burn(uint256 tokenId) public {
        address owner = ownerOf(tokenId);

        // No need to check if caller is owner or approved
        // Anyone can burn any token

        // Delete metadata
        delete _tokenMetadata[tokenId];

        // Burn the token
        _burn(tokenId);

        // Emit event
        emit HotdogBurned(msg.sender, owner, tokenId);
    }

    /**
     * @dev Verifies a token - can only be called by the contract owner
     * @param tokenId Token ID to verify
     */
    function verifyToken(uint256 tokenId) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(!_tokenMetadata[tokenId].verified, "Token already verified");

        // Set the token as verified
        _tokenMetadata[tokenId].verified = true;

        // Emit verification event
        emit HotdogVerified(tokenId, msg.sender);
    }

    /**
     * @dev Checks if a token is verified
     * @param tokenId Token ID to check
     * @return true if the token is verified, false otherwise
     */
    function isVerified(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenMetadata[tokenId].verified;
    }
}
