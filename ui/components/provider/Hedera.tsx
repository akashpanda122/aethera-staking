"use client";

import React, { FC, ReactNode, createContext, useContext, useState, useEffect, useCallback } from "react";
import { HashConnect, HashConnectTypes, MessageTypes } from "hashconnect";
import { LedgerId, AccountId } from "@hashgraph/sdk";

// Define the network type
type HederaNetwork = "testnet" | "mainnet" | "previewnet";

interface HederaContextType {
  accountId: string | null;
  isConnected: boolean;
  hashconnect: HashConnect | null;
  provider: any | null;
  connect: () => Promise<void>;
  disconnect: () => Promise<void>;
  network: HederaNetwork;
}

const HederaContext = createContext<HederaContextType>({
  accountId: null,
  isConnected: false,
  hashconnect: null,
  provider: null,
  connect: async () => {},
  disconnect: async () => {},
  network: "testnet",
});

interface HederaProviderProps {
  children: ReactNode;
  network?: HederaNetwork;
  appMetadata?: HashConnectTypes.AppMetadata;
}

export const HederaProvider: FC<HederaProviderProps> = ({ 
  children, 
  network = "testnet",
  appMetadata 
}) => {
  const [accountId, setAccountId] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [hashconnect, setHashConnect] = useState<HashConnect | null>(null);
  const [provider, setProvider] = useState<any | null>(null);

  // Default app metadata if none provided
  const defaultAppMetadata: HashConnectTypes.AppMetadata = {
    name: "Aethera Staking",
    description: "HBAR Staking Application",
    icon: typeof window !== 'undefined' ? `${window.location.origin}/logo.png` : "",
    url: typeof window !== 'undefined' ? window.location.origin : "",
  };

  const metadata = appMetadata || defaultAppMetadata;

  // Initialize HashConnect
  useEffect(() => {
    const initHashConnect = async () => {
      try {
        const hashConnectInstance = new HashConnect(
          LedgerId[network.toUpperCase() as keyof typeof LedgerId],
          metadata.url,
          true // Set to true for debug mode
        );

        setHashConnect(hashConnectInstance);

        // Set up event listeners
        hashConnectInstance.pairingEvent.on((data: MessageTypes.ApprovePairing) => {
          console.log("Pairing event:", data);
          if (data.accountIds && data.accountIds.length > 0) {
            setAccountId(data.accountIds[0]);
            setIsConnected(true);
            
            // Store pairing data in localStorage for auto-reconnect
            if (typeof window !== 'undefined') {
              localStorage.setItem('hederaAccountId', data.accountIds[0]);
              localStorage.setItem('hederaTopic', data.topic);
            }
          }
        });

        hashConnectInstance.disconnectionEvent.on(() => {
          console.log("Disconnected");
          setAccountId(null);
          setIsConnected(false);
          setProvider(null);
          
          if (typeof window !== 'undefined') {
            localStorage.removeItem('hederaAccountId');
            localStorage.removeItem('hederaTopic');
          }
        });

        hashConnectInstance.connectionStatusChangeEvent.on((state) => {
          console.log("Connection status changed:", state);
        });

        // Initialize the connection
        await hashConnectInstance.init(metadata);
        
        const provider = hashConnectInstance.getProvider(
          network,
          data.topic,
          data.accountIds[0]
        );
        setProvider(provider);

        // Try to reconnect if previously connected
        if (typeof window !== 'undefined') {
          const savedAccountId = localStorage.getItem('hederaAccountId');
          const savedTopic = localStorage.getItem('hederaTopic');
          
          if (savedAccountId && savedTopic) {
            try {
              const savedPairingData = hashConnectInstance.hcData.savedPairings.find(
                (pairing: any) => pairing.topic === savedTopic
              );
              
              if (savedPairingData) {
                setAccountId(savedAccountId);
                setIsConnected(true);
                
                const provider = hashConnectInstance.getProvider(
                  network,
                  savedTopic,
                  savedAccountId
                );
                setProvider(provider);
              }
            } catch (error) {
              console.error("Auto-reconnect failed:", error);
            }
          }
        }
      } catch (error) {
        console.error("Failed to initialize HashConnect:", error);
      }
    };

    initHashConnect();

    return () => {
      if (hashconnect) {
        hashconnect.disconnect();
      }
    };
  }, [network, metadata]);

  const connect = useCallback(async () => {
    if (!hashconnect) {
      console.error("HashConnect not initialized");
      return;
    }

    try {
      // Open pairing modal
      await hashconnect.openPairingModal();
    } catch (error) {
      console.error("Failed to connect wallet:", error);
      throw error;
    }
  }, [hashconnect]);

  const disconnect = useCallback(async () => {
    if (!hashconnect) return;

    try {
      await hashconnect.disconnect();
      setAccountId(null);
      setIsConnected(false);
      setProvider(null);
      
      if (typeof window !== 'undefined') {
        localStorage.removeItem('hederaAccountId');
        localStorage.removeItem('hederaTopic');
      }
    } catch (error) {
      console.error("Failed to disconnect wallet:", error);
      throw error;
    }
  }, [hashconnect]);

  const value: HederaContextType = {
    accountId,
    isConnected,
    hashconnect,
    provider,
    connect,
    disconnect,
    network,
  };

  return (
    <HederaContext.Provider value={value}>
      {children}
    </HederaContext.Provider>
  );
};

// Custom hook to use the Hedera context
export const useHedera = (): HederaContextType => {
  const context = useContext(HederaContext);
  if (!context) {
    throw new Error("useHedera must be used within a HederaProvider");
  }
  return context;
};