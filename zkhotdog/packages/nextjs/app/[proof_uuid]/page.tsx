"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useAccount, useContractWrite } from "wagmi";
import Image from "next/image";
import { parseEther } from "viem";
import { UseAnimation } from "~~/hooks/scaffold-eth/useAnimation";

// Types for our proof data
interface Point3D {
  x: number;
  y: number;
  z: number;
}

interface AttestationData {
  attestationId: number;
  merklePath: string[];
  leafCount: number;
  index: number;
}

interface Measurement {
  id: string;
  image_path: string;
  start_point: Point3D;
  end_point: Point3D;
  status: "Pending" | "Processing" | "Completed" | "Failed";
  attestation?: AttestationData;
}

// NFT Contract ABI for attestation-based minting
const zkHotdogAbi = [
  {
    inputs: [
      { internalType: "string", name: "imageUrl", type: "string" },
      { internalType: "uint256", name: "lengthInCm", type: "uint256" },
      { internalType: "uint256", name: "_attestationId", type: "uint256" },
      { internalType: "bytes32[]", name: "_merklePath", type: "bytes32[]" },
      { internalType: "uint256", name: "_leafCount", type: "uint256" },
      { internalType: "uint256", name: "_index", type: "uint256" },
    ],
    name: "mintWithAttestation",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

// Get contract address from environment variable
const ZK_HOTDOG_CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_ZK_HOTDOG_CONTRACT_ADDRESS || "0x0000000000000000000000000000000000000000";
// Get API base URL from environment variable
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3000";

export default function ProofStatusPage() {
  const params = useParams();
  const router = useRouter();
  const { address } = useAccount();
  const [measurement, setMeasurement] = useState<Measurement | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  
  // Animation for loading screen
  const { animation } = UseAnimation("loading");

  // Get the proof UUID from the URL
  const proofUuid = params.proof_uuid as string;

  // Contract write hook for minting NFT with attestation
  const { write: mintWithAttestation, isLoading: isMinting, isSuccess: isMintSuccess } = useContractWrite({
    address: ZK_HOTDOG_CONTRACT_ADDRESS as `0x${string}`,
    abi: zkHotdogAbi,
    functionName: "mintWithAttestation",
  });

  // Function to fetch the proof status from the backend
  const fetchProofStatus = async () => {
    try {
      setIsLoading(true);
      const response = await fetch(`${API_BASE_URL}/status/${proofUuid}`);
      
      if (!response.ok) {
        if (response.status === 404) {
          setError("Proof not found. The UUID might be incorrect.");
        } else {
          setError(`Error fetching proof status: ${response.statusText}`);
        }
        return;
      }
      
      const data = await response.json();
      setMeasurement(data);
    } catch (err) {
      setError(`Failed to fetch proof status: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setIsLoading(false);
    }
  };

  // Function to mint NFT with attestation once proof is completed
  const handleMintNft = () => {
    if (!measurement || measurement.status !== "Completed") return;
    
    // Calculate length in cm based on the 3D points
    const dx = measurement.end_point.x - measurement.start_point.x;
    const dy = measurement.end_point.y - measurement.start_point.y;
    const dz = measurement.end_point.z - measurement.start_point.z;
    const lengthInCm = Math.round(Math.sqrt(dx * dx + dy * dy + dz * dz) / 10); // Convert mm to cm

    // Create image URL by referencing the backend
    const imageUrl = `${API_BASE_URL}/img/${measurement.id}`;

    // Get attestation data
    if (!measurement.attestation) {
      console.error("Attestation data missing");
      return;
    }
    
    const { attestationId, merklePath, leafCount, index } = measurement.attestation;
    
    // Convert merklePath strings to bytes32 format
    const merklePathBytes32 = merklePath.map(path => path as `0x${string}`);
    
    mintWithAttestation({
      args: [
        imageUrl,
        BigInt(lengthInCm),
        BigInt(attestationId),
        merklePathBytes32,
        BigInt(leafCount),
        BigInt(index)
      ],
    });
  };

  // Fetch proof status on initial load and set up polling
  useEffect(() => {
    fetchProofStatus();
    
    // Poll for updates if the proof is not completed yet
    const interval = setInterval(() => {
      if (measurement && (measurement.status === "Pending" || measurement.status === "Processing")) {
        fetchProofStatus();
      }
    }, 5000); // Poll every 5 seconds
    
    return () => clearInterval(interval);
  }, [proofUuid, measurement?.status]);

  // Redirect to home page after successful minting
  useEffect(() => {
    if (isMintSuccess) {
      router.push("/");
    }
  }, [isMintSuccess, router]);

  if (isLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-4">
        <div className="w-16 h-16">{animation}</div>
        <h1 className="text-2xl font-bold mt-4">Loading Proof Status...</h1>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-4">
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded relative mb-4">
          <strong className="font-bold">Error: </strong>
          <span className="block sm:inline">{error}</span>
        </div>
        <button 
          onClick={() => router.push("/")}
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Return Home
        </button>
      </div>
    );
  }

  if (!measurement) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen p-4">
        <div className="bg-yellow-100 border border-yellow-400 text-yellow-700 px-4 py-3 rounded relative mb-4">
          <strong className="font-bold">Not Found: </strong>
          <span className="block sm:inline">Could not find the proof with UUID: {proofUuid}</span>
        </div>
        <button 
          onClick={() => router.push("/")}
          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
        >
          Return Home
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-screen p-4">
      <h1 className="text-3xl font-bold mb-4">Hotdog Proof Status</h1>
      
      <div className="w-full max-w-md bg-white rounded-lg shadow-md overflow-hidden">
        {/* Display the hotdog image */}
        <div className="w-full h-48 bg-gray-200 relative">
          <Image 
            src={`${API_BASE_URL}/img/${measurement.id}`} 
            alt="Hotdog measurement"
            fill
            style={{ objectFit: 'cover' }}
            onError={(e) => {
              const target = e.target as HTMLImageElement;
              target.onerror = null;
              target.src = "https://placehold.co/400x200?text=Image+Not+Available";
            }}
          />
        </div>
        
        <div className="p-4">
          <p className="text-xl font-semibold mb-2">Status: 
            <span className={`ml-2 ${
              measurement.status === "Completed" ? "text-green-600" : 
              measurement.status === "Failed" ? "text-red-600" : 
              "text-yellow-600"
            }`}>
              {measurement.status}
            </span>
          </p>
          
          <p className="text-gray-700 mb-2">Proof ID: {measurement.id}</p>
          
          <div className="mt-4">
            <h2 className="text-lg font-semibold mb-2">Measurement Details:</h2>
            <div className="bg-gray-100 p-3 rounded">
              <p className="text-sm">Start Point: ({measurement.start_point.x.toFixed(2)}, {measurement.start_point.y.toFixed(2)}, {measurement.start_point.z.toFixed(2)})</p>
              <p className="text-sm">End Point: ({measurement.end_point.x.toFixed(2)}, {measurement.end_point.y.toFixed(2)}, {measurement.end_point.z.toFixed(2)})</p>
              
              {/* Calculate and display length */}
              {(() => {
                const dx = measurement.end_point.x - measurement.start_point.x;
                const dy = measurement.end_point.y - measurement.start_point.y;
                const dz = measurement.end_point.z - measurement.start_point.z;
                const lengthInMm = Math.sqrt(dx * dx + dy * dy + dz * dz);
                const lengthInCm = lengthInMm / 10;
                
                return (
                  <p className="text-md font-bold mt-2">Length: {lengthInCm.toFixed(2)} cm</p>
                );
              })()}
            </div>
          </div>
        </div>
        
        {/* Display status-specific content */}
        {measurement.status === "Pending" || measurement.status === "Processing" ? (
          <div className="p-4 bg-yellow-50 flex items-center justify-center">
            <div className="w-8 h-8 mr-3">{animation}</div>
            <p className="text-yellow-700">
              {measurement.status === "Pending" ? "Waiting to start proof generation..." : "Generating proof..."}
            </p>
          </div>
        ) : measurement.status === "Failed" ? (
          <div className="p-4 bg-red-50">
            <p className="text-red-700">Failed to generate proof. Please try again.</p>
            <button 
              onClick={() => router.push("/")}
              className="mt-3 bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-4 rounded w-full"
            >
              Try Again
            </button>
          </div>
        ) : (
          // Completed status - show mint button
          <div className="p-4 bg-green-50">
            <p className="text-green-700 mb-3">Proof generated successfully! You can now mint an NFT.</p>
            <button 
              onClick={handleMintNft}
              disabled={!address || isMinting}
              className={`w-full font-bold py-2 px-4 rounded ${
                !address 
                  ? "bg-gray-400 cursor-not-allowed" 
                  : isMinting 
                    ? "bg-blue-300 cursor-wait" 
                    : "bg-blue-500 hover:bg-blue-700 text-white"
              }`}
            >
              {!address 
                ? "Connect Wallet to Mint" 
                : isMinting 
                  ? "Minting..." 
                  : "Mint NFT"}
            </button>
            {!address && (
              <p className="text-sm text-gray-600 mt-2 text-center">
                You need to connect your wallet to mint an NFT.
              </p>
            )}
          </div>
        )}
      </div>
    </div>
  );
}