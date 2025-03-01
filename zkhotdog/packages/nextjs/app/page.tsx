"use client";

import { useState } from "react";
import Image from "next/image";
import { ethers } from "ethers";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { Address } from "~~/components/scaffold-eth";

// Simple ERC721 ABI with only the functions we need
const ERC721_ABI = [
  "function balanceOf(address owner) view returns (uint256)",
  "function tokenOfOwnerByIndex(address owner, uint256 index) view returns (uint256)",
  "function tokenURI(uint256 tokenId) view returns (string)",
];

interface NFT {
  id: string;
  tokenURI: string;
  metadata?: NFTMetadata;
}

interface NFTMetadata {
  name?: string;
  description?: string;
  image?: string;
  attributes?: Array<{
    trait_type?: string;
    value?: string | boolean | number;
  }>;
  length?: number;
  verified?: boolean;
  mintedAt?: number;
}

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [nfts, setNfts] = useState<NFT[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");
  const [zoomedImage, setZoomedImage] = useState<string | null>(null);

  // Get contract address from environment variable
  const nftContractAddress = process.env.NEXT_PUBLIC_ZK_HOTDOG_CONTRACT_ADDRESS || "";

  const fetchNFTs = async () => {
    if (!connectedAddress || !nftContractAddress || !ethers.isAddress(nftContractAddress)) {
      setError("Invalid contract address in environment configuration");
      return;
    }

    setIsLoading(true);
    setError("");
    setNfts([]);

    try {
      // Connect to the provider
      const provider = new ethers.BrowserProvider(window.ethereum);
      const nftContract = new ethers.Contract(nftContractAddress, ERC721_ABI, provider);

      // Get the balance of NFTs
      const balance = await nftContract.balanceOf(connectedAddress);
      const balanceNumber = Number(balance);

      if (balanceNumber === 0) {
        setError("You don't own any NFTs from this contract");
        setIsLoading(false);
        return;
      }

      // Fetch each NFT
      const nftPromises = [];
      for (let i = 0; i < balanceNumber; i++) {
        nftPromises.push(
          (async () => {
            try {
              const tokenId = await nftContract.tokenOfOwnerByIndex(connectedAddress, i);
              let tokenURI = await nftContract.tokenURI(tokenId);
              // Handle IPFS URIs
              if (tokenURI.startsWith("ipfs://")) {
                tokenURI = `https://ipfs.io/ipfs/${tokenURI.slice(7)}`;
              }

              // Try to fetch metadata if available
              let metadata: NFTMetadata = {};
              try {
                const response = await fetch(tokenURI);
                metadata = await response.json();
                console.log("NFT metadata loaded:", metadata);
              } catch (e) {
                console.error("Error loading metadata:", e);
                // Metadata might not be available or in JSON format
              }

              metadata.mintedAt = parseInt(
                metadata.attributes?.find(attr => attr.trait_type === "Minted At")?.value as string,
              );
              metadata.verified = metadata.attributes?.find(attr => attr.trait_type === "Verified")?.value === "Yes";
              metadata.length =
                Math.round(
                  Math.sqrt(
                    parseInt(metadata.attributes?.find(attr => attr.trait_type === "Length (cm)")?.value as string),
                  ) / 10,
                ) / 100;

              return {
                id: tokenId.toString(),
                tokenURI,
                metadata,
              };
            } catch (error) {
              console.error("Error fetching NFT:", error);
              return null;
            }
          })(),
        );
      }

      const fetchedNfts = (await Promise.all(nftPromises)).filter(Boolean) as NFT[];
      setNfts(fetchedNfts);
    } catch (error) {
      console.error("Error fetching NFTs:", error);
      setError("Failed to fetch NFTs. Make sure the contract address is correct.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      {/* Zoomed image modal */}
      {zoomedImage && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-80"
          onClick={() => setZoomedImage(null)}
        >
          <div className="relative w-full h-[80vh] max-w-4xl">
            <button
              className="absolute top-4 right-4 z-10 bg-black bg-opacity-50 rounded-full p-2 text-white hover:bg-opacity-70"
              onClick={e => {
                e.stopPropagation();
                setZoomedImage(null);
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
            <Image
              src={zoomedImage}
              alt="Zoomed image"
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
      )}

      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5">
          <h1 className="text-center">
            <span className="block text-2xl mb-2">Welcome to</span>
            <span className="block text-4xl font-bold">zkHotdog</span>
          </h1>
          <div className="flex justify-center items-center space-x-2 flex-col sm:flex-row">
            <p className="my-2 font-medium">Connected Address:</p>
            <Address address={connectedAddress} />
          </div>

          <div className="mt-8 flex flex-col items-center">
            <div className="form-control w-full max-w-md">
              <div className="flex flex-col gap-2">
                <p className="text-sm">
                  Using contract address: <span className="font-mono text-base-content">{nftContractAddress}</span>
                </p>
                <button className="btn btn-primary" onClick={fetchNFTs} disabled={isLoading || !connectedAddress}>
                  {isLoading ? "Loading..." : "View NFTs"}
                </button>
              </div>
              {error && <p className="text-error mt-1">{error}</p>}
            </div>
          </div>
        </div>

        <div className="flex-grow bg-base-300 w-full mt-8 px-8 py-12">
          {isLoading ? (
            <div className="flex justify-center">
              <span className="loading loading-spinner loading-lg"></span>
            </div>
          ) : nfts.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {nfts.map(nft => (
                <div key={nft.id} className="card bg-base-100 shadow-xl">
                  {nft.metadata?.image && (
                    <figure
                      className="px-4 pt-4 cursor-pointer relative"
                      onClick={() => {
                        const imgSrc = nft.metadata?.image?.startsWith("ipfs://")
                          ? `https://ipfs.io/ipfs/${nft.metadata.image.slice(7)}`
                          : nft.metadata?.image;
                        if (!imgSrc) return;
                        setZoomedImage(imgSrc);
                      }}
                    >
                      {/* Verification status indicator strip */}
                      <div
                        className={`absolute top-0 left-0 w-full h-2 z-10 ${nft.metadata?.verified === true ? "bg-success" : "bg-error"}`}
                      ></div>

                      <Image
                        src={
                          nft.metadata.image.startsWith("ipfs://")
                            ? `https://ipfs.io/ipfs/${nft.metadata.image.slice(7)}`
                            : nft.metadata.image
                        }
                        alt={nft.metadata?.name || `NFT #${nft.id}`}
                        width={400}
                        height={300}
                        className="rounded-xl h-48 w-full object-cover"
                        onError={e => {
                          (e.target as HTMLImageElement).src = "https://placehold.co/400x400?text=No+Image";
                        }}
                      />
                      <div className="absolute bottom-2 right-2 bg-black bg-opacity-50 text-white px-2 py-1 rounded text-xs">
                        Click to zoom
                      </div>
                    </figure>
                  )}
                  <div className="card-body">
                    <h2 className="card-title">{nft.metadata?.name || `NFT #${nft.id}`}</h2>
                    <p className="text-sm">{nft.metadata?.description || "No description available"}</p>

                    {/* Simplified metadata section */}
                    <div className="grid grid-cols-2 gap-4 mt-4">
                      <div className="bg-base-200 rounded-lg p-3 text-center">
                        <p className="text-2xl font-bold text-primary">
                          {nft.metadata?.length !== undefined ? nft.metadata.length : "?"} cm
                        </p>
                        <p className="text-xs uppercase mt-1">Length</p>
                      </div>

                      <div
                        className={`rounded-lg p-3 text-center ${nft.metadata?.verified === true ? "bg-success/20" : "bg-error/20"}`}
                      >
                        <p
                          className={`text-lg font-semibold ${nft.metadata?.verified === true ? "text-success" : "text-error"}`}
                        >
                          {nft.metadata?.verified === true ? "Verified" : "Unverified"}
                        </p>
                        <p className="text-xs uppercase mt-1">Status</p>
                      </div>

                      <div className="col-span-2 bg-base-200 rounded-lg p-3 text-center">
                        <p className="text-base font-medium">
                          {nft.metadata?.mintedAt
                            ? new Date(nft.metadata.mintedAt * 1000).toLocaleString()
                            : new Date().toLocaleString()}
                        </p>
                        <p className="text-xs uppercase mt-1">Minted At</p>
                      </div>
                    </div>

                    <div className="card-actions justify-end mt-2">
                      <div className="badge badge-outline">Token ID: {nft.id}</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex justify-center items-center gap-12 flex-col sm:flex-row">
              <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 fill-secondary" viewBox="0 0 24 24">
                  <path d="M18 5H6a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V7a2 2 0 00-2-2zm-6.5 11h-2a.5.5 0 010-1h2a.5.5 0 010 1zm5 0h-3a.5.5 0 010-1h3a.5.5 0 010 1zm0-3h-10a.5.5 0 010-1h10a.5.5 0 010 1zm0-3h-10a.5.5 0 010-1h10a.5.5 0 010 1z" />
                </svg>
                <p>Click the button above to view your zkHotdog NFTs.</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  );
};

export default Home;
