"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { useParams, useRouter } from "next/navigation";
import { useAccount, useWriteContract } from "wagmi";
import { UseAnimation } from "~~/hooks/scaffold-eth/UseAnimation";

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
const ZK_HOTDOG_CONTRACT_ADDRESS =
  process.env.NEXT_PUBLIC_ZK_HOTDOG_CONTRACT_ADDRESS || "0x0000000000000000000000000000000000000000";
// Get API base URL from environment variable
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3001";

export default function ProofStatusPage() {
  const params = useParams();
  const router = useRouter();
  const { address } = useAccount();
  const [measurement, setMeasurement] = useState<Measurement | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isImageZoomed, setIsImageZoomed] = useState(false);

  // Animation for loading screen
  const { animation } = UseAnimation("loading");

  // Get the proof UUID from the URL
  const proofUuid = params.proof_uuid as string;

  // Contract write hook for minting NFT with attestation
  const {
    writeContract: mintWithAttestation,
    isPending: isMinting,
    isSuccess: isMintSuccess,
    error: mintError,
    isError: isMintError,
    reset: resetMint,
    data: txHash,
  } = useWriteContract();
  // Log transaction hash when available
  useEffect(() => {
    if (txHash) {
      console.log("Transaction submitted successfully:", txHash);
    }
  }, [txHash]);

  // Function to fetch the proof status from the backend
  const fetchProofStatus = async () => {
    try {
      setIsLoading(true);
      console.log("Fetching URL: ", `${API_BASE_URL}/status/${proofUuid}`);
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

  // State for mint status messages
  const [mintMessage, setMintMessage] = useState<{
    text: string;
    type: "info" | "success" | "error";
  } | null>(null);

  // Function to mint NFT with attestation once proof is completed
  const handleMintNft = () => {
    try {
      // Reset any previous mint error
      resetMint();
      setMintMessage(null);

      if (!measurement || measurement.status !== "Completed") {
        setMintMessage({
          text: "Cannot mint: Proof is not completed yet",
          type: "error",
        });
        return;
      }

      // Validate the contract address
      if (!ZK_HOTDOG_CONTRACT_ADDRESS || ZK_HOTDOG_CONTRACT_ADDRESS === "0x0000000000000000000000000000000000000000") {
        setMintMessage({
          text: "Contract address not configured. Please check your environment setup.",
          type: "error",
        });
        console.error("ZK_HOTDOG_CONTRACT_ADDRESS not configured", {
          address: ZK_HOTDOG_CONTRACT_ADDRESS,
        });
        return;
      }

      // Calculate length in cm based on the 3D points
      const dx = measurement.end_point.x - measurement.start_point.x;
      const dy = measurement.end_point.y - measurement.start_point.y;
      const dz = measurement.end_point.z - measurement.start_point.z;
      const lengthInCm = dx * dx + dy * dy + dz * dz; // Convert to cm (divide by 100)

      // Create image URL by referencing the backend
      const imageUrl = `${API_BASE_URL}/img/${measurement.id}`;

      // Get attestation data
      if (!measurement.attestation) {
        setMintMessage({
          text: "Attestation data missing. Cannot mint without verification.",
          type: "error",
        });
        console.error("Attestation data missing");
        return;
      }

      // Validate attestation data
      const { attestationId, merklePath, leafCount, index } = measurement.attestation;

      if (!Array.isArray(merklePath) || merklePath.length === 0) {
        setMintMessage({
          text: "Invalid merkle path data in attestation",
          type: "error",
        });
        console.error("Invalid merkle path", merklePath);
        return;
      }

      // Validate each merkle path is properly formatted as hex
      const merklePathBytes32 = merklePath.map(path => {
        if (typeof path !== "string" || !path.startsWith("0x")) {
          throw new Error(`Invalid merkle path format: ${path}`);
        }
        return path as `0x${string}`;
      });

      // Log the minting attempt
      console.log("Attempting to mint with attestation:", {
        imageUrl,
        lengthInCm,
        attestationId,
        merklePathBytes32,
        leafCount,
        index,
      });

      setMintMessage({
        text: "Preparing transaction - confirm in your wallet...",
        type: "info",
      });

      // Execute the minting transaction
      const result = mintWithAttestation({
        address: ZK_HOTDOG_CONTRACT_ADDRESS as `0x${string}`,
        abi: zkHotdogAbi,
        functionName: "mintWithAttestation",
        args: [
          imageUrl,
          BigInt(lengthInCm),
          BigInt(attestationId),
          merklePathBytes32,
          BigInt(leafCount),
          BigInt(index),
        ],
      });

      console.log("Mint transaction initiated:", result);
    } catch (error) {
      console.error("Error preparing mint transaction:", error);
      setMintMessage({
        text: `Error preparing transaction: ${error instanceof Error ? error.message : String(error)}`,
        type: "error",
      });
    }
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

  // Check environment on load
  useEffect(() => {
    // Check for valid contract address
    if (!ZK_HOTDOG_CONTRACT_ADDRESS || ZK_HOTDOG_CONTRACT_ADDRESS === "0x0000000000000000000000000000000000000000") {
      console.warn("zkHotdog contract address not properly configured", {
        address: ZK_HOTDOG_CONTRACT_ADDRESS,
      });
    } else {
      console.info("Using zkHotdog contract:", ZK_HOTDOG_CONTRACT_ADDRESS);
    }
  }, []);

  // Handle mint state changes
  useEffect(() => {
    if (isMintSuccess) {
      console.log("Mint transaction confirmed:", txHash);
      setMintMessage({
        text: "NFT minted successfully! Redirecting to home...",
        type: "success",
      });
      // Delay redirect to show success message
      const timer = setTimeout(() => {
        router.push("/");
      }, 3000);
      return () => clearTimeout(timer);
    } else if (isMintError && mintError) {
      console.error("Mint transaction failed:", mintError);
      setMintMessage({
        text: `Mint error: ${mintError.message || "Unknown error occurred"}`,
        type: "error",
      });
    }
  }, [isMintSuccess, isMintError, mintError, router, txHash]);

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

      <div className="w-full max-w-2xl bg-white dark:bg-gray-800 rounded-lg shadow-md overflow-hidden">
        {/* Display the hotdog image */}
        <div
          className="w-full bg-gray-200 relative cursor-pointer"
          style={{ minHeight: "400px", height: "auto" }}
          onClick={() => setIsImageZoomed(true)}
        >
          <Image
            src={`${API_BASE_URL}/img/${measurement.id}`}
            alt="Hotdog measurement"
            fill
            style={{ objectFit: "contain", objectPosition: "center" }}
            quality={100}
            priority
            onError={e => {
              const target = e.target as HTMLImageElement;
              target.onerror = null;
              target.src = "https://placehold.co/400x400?text=Image+Not+Available";
            }}
          />
          <div className="absolute bottom-2 right-2 bg-black bg-opacity-50 text-white px-2 py-1 rounded text-xs">
            Click to zoom
          </div>
        </div>

        <div className="p-4">
          <p className="text-xl font-semibold mb-2">
            Status:
            <span
              className={`ml-2 ${
                measurement.status === "Completed"
                  ? "text-green-600"
                  : measurement.status === "Failed"
                    ? "text-red-600"
                    : "text-yellow-600"
              }`}
            >
              {measurement.status}
            </span>
          </p>

          <p className="text-gray-700 dark:text-gray-300 mb-2">Proof ID: {measurement.id}</p>

          <div className="mt-4">
            <h2 className="text-lg font-semibold mb-2">Measurement Details:</h2>
            <div className="bg-gray-100 dark:bg-gray-700 p-3 rounded">
              <p className="text-sm dark:text-gray-200">
                Start Point: ({measurement.start_point.x.toFixed(2)}, {measurement.start_point.y.toFixed(2)},{" "}
                {measurement.start_point.z.toFixed(2)})
              </p>
              <p className="text-sm dark:text-gray-200">
                End Point: ({measurement.end_point.x.toFixed(2)}, {measurement.end_point.y.toFixed(2)},{" "}
                {measurement.end_point.z.toFixed(2)})
              </p>

              {/* Calculate and display length */}
              {(() => {
                const dx = measurement.end_point.x - measurement.start_point.x;
                const dy = measurement.end_point.y - measurement.start_point.y;
                const dz = measurement.end_point.z - measurement.start_point.z;
                const lengthInMm = Math.sqrt(dx * dx + dy * dy + dz * dz);
                const lengthInCm = lengthInMm / 1000; // Divide by 100 to convert to cm

                return <p className="text-md font-bold mt-2 dark:text-white">Length: {lengthInCm.toFixed(2)} cm</p>;
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
          <div className="p-4 bg-green-50 dark:bg-green-900">
            <p className="text-green-700 dark:text-green-300 mb-3">
              Proof generated successfully! You can now mint an NFT.
            </p>

            {mintMessage && (
              <div
                className={`mb-3 p-3 rounded border ${
                  mintMessage.type === "error"
                    ? "bg-red-100 border-red-300 text-red-700 dark:bg-red-900 dark:border-red-700 dark:text-red-300"
                    : mintMessage.type === "success"
                      ? "bg-green-100 border-green-300 text-green-700 dark:bg-green-900 dark:border-green-700 dark:text-green-300"
                      : "bg-blue-100 border-blue-300 text-blue-700 dark:bg-blue-900 dark:border-blue-700 dark:text-blue-300"
                }`}
              >
                {mintMessage.type === "error" && <span className="font-bold mr-1">Error:</span>}
                {mintMessage.text}
              </div>
            )}

            <button
              onClick={handleMintNft}
              disabled={!address || isMinting}
              className={`w-full font-bold py-2 px-4 rounded ${
                !address
                  ? "bg-gray-400 cursor-not-allowed dark:bg-gray-700 dark:text-gray-400"
                  : isMinting
                    ? "bg-blue-300 cursor-wait dark:bg-blue-700"
                    : "bg-blue-500 hover:bg-blue-700 text-white"
              }`}
            >
              {!address ? "Connect Wallet to Mint" : isMinting ? "Minting..." : "Mint NFT"}
            </button>

            {!address && (
              <p className="text-sm text-gray-600 dark:text-gray-400 mt-2 text-center">
                You need to connect your wallet to mint an NFT.
              </p>
            )}
          </div>
        )}
      </div>

      {/* Image Zoom Modal */}
      {isImageZoomed && (
        <div
          className="fixed inset-0 bg-black bg-opacity-80 z-50 flex items-center justify-center p-4"
          onClick={() => setIsImageZoomed(false)}
        >
          <div className="relative w-full max-w-4xl max-h-[90vh]">
            <button
              className="absolute top-2 right-2 bg-white dark:bg-gray-800 rounded-full p-2 z-10"
              onClick={e => {
                e.stopPropagation();
                setIsImageZoomed(false);
              }}
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                className="h-6 w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
            <div className="relative w-full h-[80vh]">
              <Image
                src={`${API_BASE_URL}/img/${measurement.id}`}
                alt="Hotdog measurement zoomed"
                fill
                style={{ objectFit: "contain" }}
                quality={100}
                priority
                onError={e => {
                  const target = e.target as HTMLImageElement;
                  target.onerror = null;
                  target.src = "https://placehold.co/800x800?text=Image+Not+Available";
                }}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
