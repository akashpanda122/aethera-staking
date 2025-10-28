'use client'
import React, { useState, useEffect, useCallback, useMemo } from "react";
import { AccountId, ContractId, ContractExecuteTransaction, ContractFunctionParameters, Hbar, ContractCallQuery } from "@hashgraph/sdk";
import './adminBody.css';
import { useHedera } from "./hooks/useHedera";
import { toast } from "sonner";
import { ToastContent } from "./ToastContent";

interface PlayerAccount {
    stakedAmount: number;
    stakedTime: number;
    durationTime: number;
}

interface AdminConfig {
    minDeposit: number;
    maxDeposit: number;
}

const CONTRACT_ID = "0.0.YOUR_CONTRACT_ID"; // Replace with your deployed contract ID
const AUTHORITY_ACCOUNT = "0.0.YOUR_AUTHORITY_ACCOUNT"; // Replace with authority account
const STAKE_NAME = "HBAR";
const ADMIN_CONFIG: AdminConfig = {
    minDeposit: 0.1,
    maxDeposit: 1000
};

export const AdminBody = () => {
    const { accountId, hashconnect, provider } = useHedera();
    
    // State management
    const [balance, setBalance] = useState<number>(0);
    const [amount, setAmount] = useState<number>(0);
    const [apy, setApy] = useState<number>(0);
    const [stakedAmount, setStakedAmount] = useState<number>(0);
    const [loading, setLoading] = useState<boolean>(false);

    // Memoized values
    const amountInTinybars = useMemo(() => amount * 1e8, [amount]);
    const apyValue = useMemo(() => Math.floor(apy * 100), [apy]); // Convert to basis points

    // Callbacks
    const getPlayerData = useCallback(async (player: string): Promise<PlayerAccount | null> => {
        if (!provider) return null;
        
        try {
            const query = new ContractCallQuery()
                .setContractId(ContractId.fromString(CONTRACT_ID))
                .setGas(100000)
                .setFunction("getPlayerData", new ContractFunctionParameters().addAddress(player));

            const result = await query.execute(provider);
            
            const stakedAmount = result.getUint256(0).toNumber();
            const stakedTime = result.getUint256(1).toNumber();
            const durationTime = result.getUint256(2).toNumber();

            return {
                stakedAmount,
                stakedTime,
                durationTime
            };
        } catch (error) {
            console.error("Error fetching player data:", error);
            return null;
        }
    }, [provider]);

    const refreshBalances = useCallback(async () => {
        if (!accountId || !provider) return;
        
        try {
            const accountBalance = await provider.getAccountBalance(accountId);
            setBalance(accountBalance.hbars.toTinybars().toNumber() / 1e8);
            
            const player = await getPlayerData(accountId);
            setStakedAmount((player?.stakedAmount || 0) / 1e8);
        } catch (error) {
            console.error("Error refreshing balances:", error);
            toast.error("Failed to refresh balances");
        }
    }, [accountId, provider, getPlayerData]);

    const handleAmountChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const value = e.target.value;
        if (!value || value.match(/^\d{1,}(\.\d{0,8})?$/)) {
            setAmount(Number(value));
        }
    }, []);

    const handleApyChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const value = e.target.value;
        if (!value || value.match(/^\d{1,}(\.\d{0,2})?$/)) {
            setApy(Number(value));
        }
    }, []);

    // Transaction handlers
    const handleTransaction = useCallback(async (
        action: () => Promise<string>,
        loadingMessage: string,
        successMessage: string,
        errorMessage: string
    ) => {
        if (!accountId) {
            toast.warning("Please connect your wallet");
            return;
        }

        const toastId = toast.loading(loadingMessage);
        setLoading(true);

        try {
            const txId = await action();
            const explorerUrl = `https://hashscan.io/testnet/transaction/${txId}`;
            
            toast.success(successMessage, {
                description: <ToastContent transactionSignature={txId} explorerUrl={explorerUrl} />,
                style: {
                    backgroundColor: "#1f1f23",
                    border: "1px solid rgba(139, 92, 246, 0.3)",
                    boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.5)",
                },
                duration: 8000,
                id: toastId
            });

            await refreshBalances();
        } catch (err) {
            console.error(`Error: ${errorMessage}`, err);
            toast.error(errorMessage, {
                description: err instanceof Error ? err.message : String(err),
                style: {
                    border: "1px solid rgba(239, 68, 68, 0.3)",
                    background: "linear-gradient(to right, rgba(40, 27, 27, 0.95), rgba(28, 23, 23, 0.95))",
                },
                duration: 5000,
                id: toastId
            });
        } finally {
            setLoading(false);
        }
    }, [accountId, refreshBalances]);

    const adminInitialise = useCallback(async () => {
        if (!accountId || !hashconnect || !provider) {
            toast.warning("Please connect your wallet");
            return;
        }

        await handleTransaction(
            async () => {
                const transaction = new ContractExecuteTransaction()
                    .setContractId(ContractId.fromString(CONTRACT_ID))
                    .setGas(300000)
                    .setFunction(
                        "initialize",
                        new ContractFunctionParameters()
                            .addUint256(100) // Initial APY value
                    );

                const signer = hashconnect.getSigner(AccountId.fromString(accountId));
                const txResponse = await transaction.executeWithSigner(signer);
                const receipt = await txResponse.getReceiptWithSigner(signer);
                
                return txResponse.transactionId.toString();
            },
            "Initializing contract...",
            "Contract Initialized Successfully!",
            "Initialization Failed"
        );
    }, [accountId, hashconnect, provider, handleTransaction]);

    const adminDeposit = useCallback(async () => {
        if (!accountId || !hashconnect || !provider) {
            toast.warning("Please connect your wallet");
            return;
        }

        if (!amount || amount <= 0) {
            toast.error("Please enter a valid deposit amount");
            return;
        }

        if (amount < ADMIN_CONFIG.minDeposit) {
            toast.error(`Minimum deposit amount is ${ADMIN_CONFIG.minDeposit} HBAR`);
            return;
        }

        if (amount > ADMIN_CONFIG.maxDeposit) {
            toast.error(`Maximum deposit amount is ${ADMIN_CONFIG.maxDeposit} HBAR`);
            return;
        }

        const accountBalance = await provider.getAccountBalance(accountId);
        const balanceInHbar = accountBalance.hbars.toTinybars().toNumber() / 1e8;
        
        if (amount > balanceInHbar) {
            toast.error(`Insufficient balance. You have ${balanceInHbar.toFixed(4)} HBAR`);
            return;
        }

        await handleTransaction(
            async () => {
                const transaction = new ContractExecuteTransaction()
                    .setContractId(ContractId.fromString(CONTRACT_ID))
                    .setGas(300000)
                    .setPayableAmount(new Hbar(amount))
                    .setFunction("adminDeposit");

                const signer = hashconnect.getSigner(AccountId.fromString(accountId));
                const txResponse = await transaction.executeWithSigner(signer);
                const receipt = await txResponse.getReceiptWithSigner(signer);
                
                return txResponse.transactionId.toString();
            },
            "Processing deposit...",
            "Deposit Successful!",
            "Deposit Failed"
        );

        setAmount(0);
    }, [amount, accountId, hashconnect, provider, handleTransaction]);

    const adminWithdraw = useCallback(async () => {
        if (!accountId || !hashconnect || !provider) {
            toast.warning("Please connect your wallet");
            return;
        }

        await handleTransaction(
            async () => {
                const transaction = new ContractExecuteTransaction()
                    .setContractId(ContractId.fromString(CONTRACT_ID))
                    .setGas(300000)
                    .setFunction("adminWithdraw");

                const signer = hashconnect.getSigner(AccountId.fromString(accountId));
                const txResponse = await transaction.executeWithSigner(signer);
                const receipt = await txResponse.getReceiptWithSigner(signer);
                
                return txResponse.transactionId.toString();
            },
            "Processing withdrawal...",
            "Withdrawal Successful!",
            "Withdrawal Failed"
        );
    }, [accountId, hashconnect, provider, handleTransaction]);

    const adminConfig = useCallback(async () => {
        if (!accountId || !hashconnect || !provider) {
            toast.warning("Please connect your wallet");
            return;
        }

        if (!apy || apy <= 0) {
            toast.error("Please enter a valid APY value");
            return;
        }

        await handleTransaction(
            async () => {
                const transaction = new ContractExecuteTransaction()
                    .setContractId(ContractId.fromString(CONTRACT_ID))
                    .setGas(300000)
                    .setFunction(
                        "updateAPY",
                        new ContractFunctionParameters()
                            .addUint256(apyValue)
                    );

                const signer = hashconnect.getSigner(AccountId.fromString(accountId));
                const txResponse = await transaction.executeWithSigner(signer);
                const receipt = await txResponse.getReceiptWithSigner(signer);
                
                return txResponse.transactionId.toString();
            },
            "Updating APY configuration...",
            "APY Configuration Updated!",
            "Failed to Update APY"
        );
    }, [accountId, hashconnect, provider, apyValue, handleTransaction, apy]);

    // Effects
    useEffect(() => {
        refreshBalances();
    }, [accountId, refreshBalances]);

    return (
        <div className="main">
            <div className="main__block">
                <p className="main__block-title">{STAKE_NAME} Staking Admin</p>
                <div className="main__block-balance">
                    <p className="main__block-balance-sub">
                        Balance &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                        {balance.toFixed(4)} {STAKE_NAME}
                    </p>
                    <p className="main__block-balance-sub">
                        Staked Balance {stakedAmount.toFixed(4)} {STAKE_NAME}
                    </p>
                </div>

                <button 
                    className="main__block-stake-btn" 
                    onClick={adminInitialise}
                    disabled={loading}
                >
                    Admin Initialise {STAKE_NAME}
                </button>      

                <div className="main__block-stake-block">
                    <div className="main__block-stake-block--input-gr">
                        <p className="main__block-stake-block--title">Deposit Amount &nbsp;</p>
                        <input 
                            className="main__block-stake-block--input" 
                            value={amount} 
                            step="0.01" 
                            type="number" 
                            onChange={handleAmountChange}
                            disabled={loading}
                            placeholder="0.00"
                        /> 
                        {STAKE_NAME}
                    </div>
                </div>
                
                <button 
                    className="main__block-stake-btn" 
                    onClick={adminDeposit}
                    disabled={loading}
                >
                    Admin Deposit {STAKE_NAME}
                </button> 

                <div className="main_create-account" />
                
                <button 
                    className="main__block-stake-btn" 
                    onClick={adminWithdraw}
                    disabled={loading}
                >
                    Admin Withdraw {STAKE_NAME}
                </button> 

                <div className="main_create-account" />
                
                <div className="main__block-stake-block">
                    <div className="main__block-stake-block--input-gr">
                        <p className="main__block-stake-block--title">APY &nbsp;</p>
                        <input 
                            className="main__block-stake-block--input" 
                            value={apy} 
                            step="0.01" 
                            type="number" 
                            onChange={handleApyChange}
                            disabled={loading}
                            placeholder="0.00"
                        />
                    </div>
                </div>

                <button 
                    className="main__block-stake-btn" 
                    onClick={adminConfig}
                    disabled={loading}
                >
                    Admin Config {STAKE_NAME}
                </button>                  
            </div>
        </div>
    );
};