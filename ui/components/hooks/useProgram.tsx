"use client";

import { useContext, useEffect, useState } from "react";
import { 
  Client, 
  AccountId, 
  ContractId, 
  PrivateKey,
  Hbar,
  AccountBalanceQuery,
  TransferTransaction
} from "@hashgraph/sdk";
import { HashConnect } from "hashconnect";

// Import the Hedera context (assuming it's exported from the provider)
import { HederaContext } from "@/components/provider/Hedera";

// Contract configuration
const CONTRACT_ID = process.env.NEXT_PUBLIC_CONTRACT_ID || "0.0.YOUR_CONTRACT_ID";
const NETWORK = process.env.NEXT_PUBLIC_HEDERA_NETWORK || "testnet";

interface UseHederaReturn {
  contractId: ContractId;
  accountId: string | null;
  isConnected: boolean;
  hashconnect: HashConnect | null;
  provider: any | null;
  client: Client | null;
  connect: () => Promise<void>;
  disconnect: () => Promise<void>;
  network: string;
}

/**
 * A hook that provides access to the Hedera network, smart contract,
 * connected wallet, and client.
 * This hook handles the basic setup for Hedera interactions.
 */
export function useHedera(): UseHederaReturn {
  const context = useContext(HederaContext);
  
  if (!context) {
    throw new Error("useHedera must be used within a HederaProvider");
  }

  const { 
    accountId, 
    isConnected, 
    hashconnect, 
    provider,
    connect,
    disconnect,
    network 
  } = context;

  const [client, setClient] = useState<Client | null>(null);

  // Initialize Hedera Client
  useEffect(() => {
    const initializeClient = () => {
      try {
        let hederaClient: Client;

        if (network === "mainnet") {
          hederaClient = Client.forMainnet();
        } else if (network === "previewnet") {
          hederaClient = Client.forPreviewnet();
        } else {
          hederaClient = Client.forTestnet();
        }

        setClient(hederaClient);
      } catch (error) {
        console.error("Failed to initialize Hedera client:", error);
      }
    };

    initializeClient();

    return () => {
      if (client) {
        client.close();
      }
    };
  }, [network]);

  // Fund connected wallet with testnet HBAR (only on testnet)
  useEffect(() => {
    const fundTestnetAccount = async () => {
      if (!accountId || !provider || network !== "testnet") return;

      try {
        const balance = await provider.getAccountBalance(accountId);
        const hbarBalance = balance.hbars.toBigNumber().toNumber();

        // If balance is less than 10 HBAR, request testnet funding
        if (hbarBalance < 10) {
          console.log("Low balance detected. Please visit https://portal.hedera.com/faucet to fund your testnet account.");
          
          // Optionally, you can implement automatic faucet funding
          // Note: Hedera testnet faucet requires manual intervention or API integration
          await requestTestnetFunding(accountId);
        }
      } catch (error) {
        console.error("Error checking balance:", error);
      }
    };

    fundTestnetAccount();
  }, [accountId, provider, network]);

  // Get the contract ID
  const contractId = ContractId.fromString(CONTRACT_ID);

  return {
    contractId,
    accountId,
    isConnected,
    hashconnect,
    provider,
    client,
    connect,
    disconnect,
    network,
  };
}

/**
 * Helper function to request testnet HBAR from faucet
 * Note: This requires integration with Hedera testnet faucet API
 */
async function requestTestnetFunding(accountId: string): Promise<void> {
  try {
    // Option 1: Direct API call to Hedera faucet (if available)
    const response = await fetch('https://faucet.hedera.com/api/v1/fund', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        accountId: accountId,
      }),
    });

    if (response.ok) {
      console.log("Testnet funding successful!");
    } else {
      console.log("Please manually fund your account at: https://portal.hedera.com/faucet");
    }
  } catch (error) {
    console.error("Faucet funding error:", error);
    console.log("Please manually fund your account at: https://portal.hedera.com/faucet");
  }
}

/**
 * Helper hook for contract operations
 * Provides commonly used contract interaction methods
 */
export function useContract() {
  const { contractId, accountId, hashconnect, provider, isConnected } = useHedera();

  /**
   * Execute a contract function
   */
  const executeContract = async (
    functionName: string,
    parameters?: any,
    payableAmount?: Hbar
  ) => {
    if (!isConnected || !accountId || !hashconnect) {
      throw new Error("Wallet not connected");
    }

    const { ContractExecuteTransaction, ContractFunctionParameters } = await import("@hashgraph/sdk");

    try {
      let transaction = new ContractExecuteTransaction()
        .setContractId(contractId)
        .setGas(300000)
        .setFunction(functionName, parameters);

      if (payableAmount) {
        transaction = transaction.setPayableAmount(payableAmount);
      }

      const signer = hashconnect.getSigner(AccountId.fromString(accountId));
      const txResponse = await transaction.executeWithSigner(signer);
      const receipt = await txResponse.getReceiptWithSigner(signer);

      return {
        transactionId: txResponse.transactionId.toString(),
        receipt,
        status: receipt.status.toString(),
      };
    } catch (error) {
      console.error("Contract execution error:", error);
      throw error;
    }
  };

  /**
   * Query a contract function (read-only)
   */
  const queryContract = async (
    functionName: string,
    parameters?: any
  ) => {
    if (!provider) {
      throw new Error("Provider not initialized");
    }

    const { ContractCallQuery } = await import("@hashgraph/sdk");

    try {
      const query = new ContractCallQuery()
        .setContractId(contractId)
        .setGas(100000)
        .setFunction(functionName, parameters);

      const result = await query.execute(provider);
      return result;
    } catch (error) {
      console.error("Contract query error:", error);
      throw error;
    }
  };

  return {
    executeContract,
    queryContract,
    contractId,
  };
}