// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./IZkVerify.sol";
import "./IZkHotdogServiceManager.sol";

/**
 * @title zkHotdog NFT
 * @dev ERC721 contract for zkHotdog project with Groth16 proof verification
 */
contract ZkHotdog is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // zkVerify contract
    address public zkVerify;

    // vkey for our circuit
    bytes32 public vkey;

    // ZkHotdog Service Manager address
    address public serviceManager;

    // Proving system ID for groth16
    bytes32 public constant PROVING_SYSTEM_ID =
        keccak256(abi.encodePacked("groth16"));

    // Struct to store metadata for each token
    struct TokenMetadata {
        string imageUrl;
        uint256 lengthInCm;
        uint256 mintedAt;
        bool verified;
        uint32 taskIndex; // EigenLayer AVS task index
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

    // Event emitted when a token is verified by the owner or service manager
    event HotdogVerified(uint256 indexed tokenId, address indexed verifier);

    error TokenIsNontransferable();
    error NotAuthorized();

    /**
     * @dev Constructor initializes the contract with a name and symbol
     * @param _zkVerify The zkVerify contract address
     * @param _vkey The verification key hash
     */
    constructor(
        address _zkVerify,
        bytes32 _vkey
    ) ERC721("zkHotdog", "HOTDOG") Ownable() {
        _nextTokenId = 1;
        zkVerify = _zkVerify;
        vkey = _vkey;
    }

    /**
     * @dev Modifier to ensure only authorized addresses can call a function
     */
    modifier onlyAuthorized() {
        if (msg.sender != owner() && msg.sender != serviceManager) {
            revert NotAuthorized();
        }
        _;
    }

    /**
     * @dev Helper function to change endianness for groth16 proofs
     * @param input The input to change endianness
     * @return v The value with changed endianness
     */
    function _changeEndianess(uint256 input) internal pure returns (uint256 v) {
        v = input;
        // swap bytes
        v =
            ((v &
                0xFF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00) >>
                8) |
            ((v &
                0x00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF00FF) <<
                8);
        // swap 2-byte long pairs
        v =
            ((v &
                0xFFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000) >>
                16) |
            ((v &
                0x0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF0000FFFF) <<
                16);
        // swap 4-byte long pairs
        v =
            ((v &
                0xFFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000) >>
                32) |
            ((v &
                0x00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF00000000FFFFFFFF) <<
                32);
        // swap 8-byte long pairs
        v =
            ((v &
                0xFFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF0000000000000000) >>
                64) |
            ((v &
                0x0000000000000000FFFFFFFFFFFFFFFF0000000000000000FFFFFFFFFFFFFFFF) <<
                64);
        // swap 16-byte long pairs
        v = (v >> 128) | (v << 128);
    }

    /**
     * @dev Mint a new token with attestation verification and create verification task
     * @param imageUrl URL pointing to the image of the hotdog
     * @param lengthInCm Length of the hotdog in centimeters
     * @param _attestationId The attestation ID from zkVerify
     * @param _merklePath The merkle path for attestation proof
     * @param _leafCount The number of leaves in the merkle tree
     * @param _index The index of the leaf in the merkle tree
     * @return tokenId The ID of the newly minted token
     */
    function mintWithAttestation(
        string memory imageUrl,
        uint256 lengthInCm,
        uint256 _attestationId,
        bytes32[] calldata _merklePath,
        uint256 _leafCount,
        uint256 _index
    ) public returns (uint256) {
        require(bytes(imageUrl).length > 0, "Image URL cannot be empty");

        // Create the leaf digest
        bytes32 leaf = keccak256(
            abi.encodePacked(
                PROVING_SYSTEM_ID,
                vkey,
                keccak256(abi.encodePacked(_changeEndianess(lengthInCm)))
            )
        );

        // Verify the attestation proof
        require(
            IZkVerifyAttestation(zkVerify).verifyProofAttestation(
                _attestationId,
                leaf,
                _merklePath,
                _leafCount,
                _index
            ),
            "Invalid attestation proof"
        );

        // Get the current token ID and increment for next mint
        uint256 tokenId = _nextTokenId++;

        // Mint the token to the caller
        _safeMint(msg.sender, tokenId);

        // Store the metadata
        _tokenMetadata[tokenId] = TokenMetadata({
            imageUrl: imageUrl,
            lengthInCm: lengthInCm,
            mintedAt: block.timestamp,
            verified: false, // Will be verified by EigenLayer AVS
            taskIndex: 0 // No task yet
        });

        // If service manager is set, create a verification task
        if (serviceManager != address(0)) {
            // Create verification task using the service manager
            try IZkHotdogServiceManager(serviceManager).createNewTask(tokenId, imageUrl) returns (
                IZkHotdogServiceManager.Task memory /* task */
            ) {
                // Get the task index from the service manager
                uint32 taskIndex = IZkHotdogServiceManager(serviceManager).latestTaskNum() - 1;
                
                // Update task index in token metadata
                _tokenMetadata[tokenId].taskIndex = taskIndex;
            } catch {
                // If task creation fails, we still allow the mint to succeed
                // This ensures the user gets their NFT even if task creation has an issue
            }
        }

        // Emit event
        emit HotdogMinted(msg.sender, tokenId, imageUrl, lengthInCm);
        
        return tokenId;
    }

    /**
     * @dev Update task index for a token - can only be called by the service manager
     * @param tokenId Token ID to update
     * @param taskIndex New task index
     */
    function setTaskIndex(uint256 tokenId, uint32 taskIndex) external {
        require(
            msg.sender == serviceManager,
            "Only service manager can set task index"
        );
        require(_exists(tokenId), "Token does not exist");
        _tokenMetadata[tokenId].taskIndex = taskIndex;
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
                        '"},',
                        '{"trait_type": "Task Index", "value": "',
                        uint256(metadata.taskIndex).toString(),
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
    function _exists(uint256 tokenId) internal view override returns (bool) {
        return super._exists(tokenId);
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

    /**
     * @dev Override the _transfer function to prevent transfers (soulbound)
     */
    function _transfer(address, address, uint256) internal virtual override {
        // Prevent transfers (soulbound tokens)
        revert TokenIsNontransferable();
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
     * @dev Verifies a token - can only be called by authorized addresses
     * @param tokenId Token ID to verify
     */
    function verifyToken(uint256 tokenId) external onlyAuthorized {
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

    /**
     * @dev Gets the task index for a token
     * @param tokenId Token ID to check
     * @return taskIndex The AVS task index
     */
    function getTaskIndex(uint256 tokenId) public view returns (uint32) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenMetadata[tokenId].taskIndex;
    }

    /**
     * @dev Set the service manager address - can only be called by owner
     * @param _serviceManager The new service manager address
     */
    function setServiceManager(address _serviceManager) external onlyOwner {
        require(_serviceManager != address(0), "Invalid address");
        serviceManager = _serviceManager;
    }
}
