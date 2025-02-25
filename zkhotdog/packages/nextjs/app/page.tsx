"use client";

import { useState } from "react";
import Image from "next/image";
import { ethers } from "ethers";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { BugAntIcon } from "@heroicons/react/24/outline";
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
  metadata?: {
    name?: string;
    description?: string;
    image?: string;
  };
}

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [nftContractAddress, setNftContractAddress] = useState("");
  const [nfts, setNfts] = useState<NFT[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const fetchNFTs = async () => {
    if (!connectedAddress || !nftContractAddress || !ethers.isAddress(nftContractAddress)) {
      setError("Please enter a valid contract address");
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
              let metadata = {};
              try {
                const response = await fetch(tokenURI);
                metadata = await response.json();
              } catch (e) {
                // Metadata might not be available or in JSON format
              }

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
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5">
          <h1 className="text-center">
            <span className="block text-2xl mb-2">Welcome to</span>
            <span className="block text-4xl font-bold">NFT Viewer</span>
          </h1>
          <div className="flex justify-center items-center space-x-2 flex-col sm:flex-row">
            <p className="my-2 font-medium">Connected Address:</p>
            <Address address={connectedAddress} />
          </div>

          <div className="mt-8 flex flex-col items-center">
            <div className="form-control w-full max-w-md">
              <label className="label">
                <span className="label-text">NFT Contract Address</span>
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="0x..."
                  className="input input-bordered w-full"
                  value={nftContractAddress}
                  onChange={e => setNftContractAddress(e.target.value)}
                />
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
                    <figure className="px-4 pt-4">
                      <Image
                        src={
                          nft.metadata.image.startsWith("ipfs://")
                            ? `https://ipfs.io/ipfs/${nft.metadata.image.slice(7)}`
                            : nft.metadata.image
                        }
                        alt={nft.metadata?.name || `NFT #${nft.id}`}
                        className="rounded-xl h-48 w-full object-cover"
                        onError={e => {
                          (e.target as HTMLImageElement).src = "https://placehold.co/400x400?text=No+Image";
                        }}
                      />
                    </figure>
                  )}
                  <div className="card-body">
                    <h2 className="card-title">{nft.metadata?.name || `NFT #${nft.id}`}</h2>
                    <p className="text-sm truncate">{nft.metadata?.description || "No description available"}</p>
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
                <BugAntIcon className="h-8 w-8 fill-secondary" />
                <p>Enter an NFT contract address above to view your NFTs.</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </>
  );
};

export default Home;
