// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IZkVerify.sol";

/**
 * @title MockZkVerify
 * @dev Mock implementation of zkVerify attestation contract for testing
 */
contract MockZkVerify is IZkVerifyAttestation {
    // Mock function that always returns true
    function verifyProofAttestation(
        uint256 /* _attestationId */,
        bytes32 /* _leaf */,
        bytes32[] calldata /* _merklePath */,
        uint256 /* _leafCount */,
        uint256 /* _index */
    ) external pure override returns (bool) {
        // Always return true for testing
        return true;
    }

    // Mock submission functions (do nothing)
    function submitAttestation(
        uint256 /* _attestationId */,
        bytes32 /* _proofsAttestation */
    ) external override {}

    function submitAttestationBatch(
        uint256[] calldata /* _attestationIds */,
        bytes32[] calldata /* _proofsAttestation */
    ) external override {}
}

