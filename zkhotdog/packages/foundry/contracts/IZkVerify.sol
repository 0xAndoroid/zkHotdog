// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IZkVerifyAttestation {

    function submitAttestation(
        uint256 _attestationId,
        bytes32 _proofsAttestation) external;

    function submitAttestationBatch(
        uint256[] calldata _attestationIds,
        bytes32[] calldata _proofsAttestation) external;

    function verifyProofAttestation(
        uint256 _attestationId,
        bytes32 _leaf,
        bytes32[] calldata _merklePath,
        uint256 _leafCount,
        uint256 _index) external returns (bool);
}