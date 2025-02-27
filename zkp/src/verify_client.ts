import { zkVerifySession, ZkVerifyEvents, VerifyTransactionInfo } from 'zkverifyjs';
import fs from 'fs';
import path from 'path';

/**
 * Submit a proof to the zkVerify network for verification
 * @param proofId The UUID of the proof to verify
 * @returns Promise with the verification result
 */
export async function verifyProof(proofId: string): Promise<boolean> {
  try {
    console.log(`Submitting proof ${proofId} to zkVerify network...`);
    
    // Construct paths to proof files
    const proofDir = path.join(process.cwd(), 'proofs', proofId);
    const proofPath = path.join(proofDir, 'proof.json');
    const publicPath = path.join(proofDir, 'public.json');
    
    if (!fs.existsSync(proofPath) || !fs.existsSync(publicPath)) {
      throw new Error(`Required files not found in directory: ${proofDir}`);
    }
    
    // Read proof and public input files
    const proofData = JSON.parse(fs.readFileSync(proofPath, 'utf8'));
    const publicInputs = JSON.parse(fs.readFileSync(publicPath, 'utf8'));
    
    // Load verification key
    const vkPath = path.join(process.cwd(), 'keys', 'verification_key.json');
    
    if (!fs.existsSync(vkPath)) {
      throw new Error(`Verification key not found: ${vkPath}`);
    }
    
    const vk = JSON.parse(fs.readFileSync(vkPath, 'utf8'));
    
    // Get seed phrase from environment variable
    const seedPhrase = process.env.ZK_VERIFY_SEED_PHRASE;
    if (!seedPhrase) {
      throw new Error('Seed phrase is required. Set ZK_VERIFY_SEED_PHRASE environment variable.');
    }
    
    // Start a session with zkVerify network
    const session = await zkVerifySession.start()
      .Testnet() // Use testnet network
      .withAccount(seedPhrase); // Use account from seed phrase
    
    console.log('Connected to zkVerify network');
    
    try {
      // Execute the verification transaction
      const { events, transactionResult } = await session.verify()
        .groth16() // Use Groth16 proof system
        .waitForPublishedAttestation() // Wait for published attestation
        .execute({ 
          proofData: {
            vk: vk,
            proof: proofData,
            publicSignals: publicInputs
          }
        });
      
      console.log('Verification request submitted, waiting for confirmation...');
      
      // Set up event listeners for transaction status updates
      events.on(ZkVerifyEvents.IncludedInBlock, (eventData) => {
        console.log('Transaction included in block:', eventData.blockHash);
      });
      
      events.on(ZkVerifyEvents.Finalized, (eventData) => {
        console.log('Transaction finalized in block:', eventData.blockHash);
      });
      
      events.on(ZkVerifyEvents.AttestationConfirmed, (eventData) => {
        console.log('Attestation confirmed with ID:', eventData.attestationId);
      });
      
      events.on('error', (error) => {
        console.error('Transaction error:', error);
      });
      
      // Wait for the transaction to complete
      const transactionInfo: VerifyTransactionInfo = await transactionResult;
      
      console.log(`Verification completed. Result: ${transactionInfo.attestationConfirmed}`);
      
      return transactionInfo.attestationConfirmed === true;
    } finally {
      // Close the session when done
      await session.close();
    }
  } catch (error) {
    console.error('Proof verification failed:', error);
    return false;
  }
}

// If this script is called directly with a proof ID
if (require.main === module) {
  // Check if proof ID was provided as command line argument
  const proofId = process.argv[2];
  
  if (!proofId) {
    console.error('Please provide a proof ID as an argument');
    process.exit(1);
  }
  
  verifyProof(proofId)
    .then(result => {
      console.log(`Proof verification ${result ? 'succeeded' : 'failed'}`);
      process.exit(result ? 0 : 1);
    })
    .catch(error => {
      console.error('Error:', error);
      process.exit(1);
    });
}