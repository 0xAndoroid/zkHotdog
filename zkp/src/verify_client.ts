// Import zkverifyjs - based on their documentation
import {
  zkVerifySession,
  Library,
  CurveType,
  ZkVerifyEvents,
} from "zkverifyjs";
import * as fs from "fs";
import * as path from "path";

/**
 * Submit a proof to the zkVerify network for verification
 * @param proofId The UUID of the proof to verify
 * @returns Promise with the verification result
 */
export async function verifyProof(proofId: string): Promise<boolean> {
  try {
    console.log(`Submitting proof ${proofId} to zkVerify network...`);

    // Construct paths to proof files
    const proofDir = path.join(process.cwd(), "proofs", proofId);
    const proofPath = path.join(proofDir, "proof.json");
    const publicPath = path.join(proofDir, "public.json");
    const vkPath = path.join(process.cwd(), "keys", "verification_key.json");

    if (
      !fs.existsSync(proofPath) ||
      !fs.existsSync(publicPath) ||
      !fs.existsSync(vkPath)
    ) {
      throw new Error(`Required files not found. Please check the paths.`);
    }

    // Read proof, public input files, and verification key
    const proof = JSON.parse(fs.readFileSync(proofPath, "utf8"));
    const publicSignals = JSON.parse(fs.readFileSync(publicPath, "utf8"));
    const key = JSON.parse(fs.readFileSync(vkPath, "utf8"));

    console.log("Loaded proof data and verification key");

    // Get seed phrase from environment variable
    const seedPhrase = process.env.ZK_VERIFY_SEED_PHRASE;
    if (!seedPhrase) {
      throw new Error(
        "Seed phrase is required. Set ZK_VERIFY_SEED_PHRASE environment variable.",
      );
    }

    // Start a session with zkVerify network
    const session = await zkVerifySession
      .start()
      .Testnet() // Use testnet network
      .withAccount(seedPhrase); // Use account from seed phrase

    console.log("Connected to zkVerify network");

    try {
      // Execute verification with the provided key
      const { events, transactionResult } = await session
        .verify()
        .groth16(Library.snarkjs, CurveType.bn128)
        .waitForPublishedAttestation()
        .execute({
          proofData: {
            proof: proof,
            publicSignals: publicSignals,
            vk: key,
          },
        });

      console.log(
        "Verification request submitted, waiting for confirmation...",
      );

      // Set up event listeners
      events.on(ZkVerifyEvents.IncludedInBlock, (eventData) => {
        console.log("Transaction included in block:", eventData);
      });

      // Store leaf digests by transaction ID
      let leafDigest: string | undefined = undefined;
      let attestationId: number | undefined = undefined;

      events.on(ZkVerifyEvents.Finalized, (eventData) => {
        console.log("Transaction finalized:", eventData);
        if (eventData.leafDigest && eventData.attestationId) {
          // Store the leaf digest mapped to the transaction ID
          leafDigest = eventData.leafDigest;
          console.log(
            `Stored leaf digest ${eventData.leafDigest} for transaction ${eventData.attestationId}`,
          );
        }
      });

      events.on(ZkVerifyEvents.AttestationConfirmed, async (eventData) => {
        console.log("Attestation Confirmed", eventData);

        // Check if all required fields are present
        if (!eventData.id) {
          console.error("Error: Missing attestation ID in event data");
          return;
        }

        attestationId = eventData.id;
      });

      events.on("error", (error) => {
        console.error("Transaction error:", error);
      });

      // Wait for the transaction to complete
      await transactionResult;

      console.log(
        `Calling poe with attestation ID: ${attestationId}, leaf digest: ${leafDigest}`,
      );
      const proofDetails = await session.poe(attestationId!, leafDigest!);

      console.log("Proof of existence details:", proofDetails);

      const merklePath = proofDetails.proof;
      const leafCount = proofDetails.numberOfLeaves;
      const index = proofDetails.leafIndex;

      console.log(
        `Writing attestation data with ID: ${attestationId}, merklePath: ${JSON.stringify(merklePath)}, leafCount: ${leafCount}, index: ${index}`,
      );

      // Save full attestation data for frontend use
      fs.writeFileSync(
        path.join(proofDir, "attestation.json"),
        JSON.stringify(
          {
            attestationId: attestationId,
            merklePath: merklePath,
            leafCount: leafCount,
            index: index,
          },
          null,
          2,
        ),
      );

      return true; // If we get here without errors, verification succeeded
    } finally {
      // Close the session when done
      await session.close();
    }
  } catch (error) {
    console.error("Proof verification failed:", error);
    return false;
  }
}

// If this script is called directly with a proof ID
if (require.main === module) {
  // Check if proof ID was provided as command line argument
  const proofId = process.argv[2];

  if (!proofId) {
    console.error("Please provide a proof ID as an argument");
    process.exit(1);
  }

  verifyProof(proofId)
    .then((result) => {
      console.log(`Proof verification ${result ? "succeeded" : "failed"}`);
      process.exit(result ? 0 : 1);
    })
    .catch((error) => {
      console.error("Error:", error);
      process.exit(1);
    });
}
