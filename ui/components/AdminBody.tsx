'use client'
import React, { useState, useEffect, useCallback, useMemo } from "react";
import { PublicKey } from '@solana/web3.js';
import { useConnection } from '@solana/wallet-adapter-react';
import './adminBody.css';
import { useProgram } from "./hooks/useProgram";
import * as anchor from "@coral-xyz/anchor";
import { toast } from "sonner";
import { ToastContent } from "./ToastContent";

interface PlayerAccount {
    stakedAmount: number;
    stakedTime: anchor.BN;
    durationTime: anchor.BN;
}

interface AdminConfig {
    minDeposit: number;
    maxDeposit: number;
}

const authority = new PublicKey("7ivunejTCC3g6gWqYZqVRpthdyj29vPmVas5YcCy5Yh8");
const STAKE_NAME = "SOL";
const ADMIN_CONFIG: AdminConfig = {
    minDeposit: 0.1,
    maxDeposit: 1000
};

export const AdminBody = () => {
    const { program, publicKey } = useProgram();
    const { connection } = useConnection();
    
    // State management
    const [balance, setBalance] = useState<number>(0);
    const [amount, setAmount] = useState<number>(0);
    const [apy, setApy] = useState<number>(0);
    const [stakedAmount, setStakedAmount] = useState<number>(0);
    const [loading, setLoading] = useState<boolean>(false);

    // Memoized values
    const amountInLamports = useMemo(() => amount * 1e9, [amount]);
    const apyInBasisPoints = useMemo(() => new anchor.BN(apy), [apy]);

    // Callbacks
    const getPlayerData = useCallback(async (player: PublicKey): Promise<PlayerAccount | null> => {
        const [playerPDA] = PublicKey.findProgramAddressSync(
            [Buffer.from('player'), authority.toBuffer(), player.toBuffer()],
            program.programId
        );
        try {
            return await program.account.playerAccount.fetch(playerPDA) as PlayerAccount;
        } catch {
            return null;
        }
    }, [program]);

    const refreshBalances = useCallback(async () => {
        if (!publicKey) return;
        
        try {
            const balance = await connection.getBalance(publicKey);
            setBalance(balance / 1e9);
            
            const player = await getPlayerData(publicKey);
            setStakedAmount(Number(player?.stakedAmount || 0) / 1e9);
        } catch (error) {
            console.error("Error refreshing balances:", error);
            toast.error("Failed to refresh balances");
        }
    }, [publicKey, connection, getPlayerData]);

    const handleAmountChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const value = e.target.value;
        if (!value || value.match(/^\d{1,}(\.\d{0,2})?$/)) {
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
        if (!publicKey) {
            toast.warning("Please connect your wallet");
            return;
        }

        const toastId = toast.loading(loadingMessage);
        setLoading(true);

        try {
            const txSignature = await action();
            const explorerUrl = `https://explorer.solana.com/tx/${txSignature}?cluster=devnet`;
            
            toast.success(successMessage, {
                description: <ToastContent transactionSignature={txSignature} explorerUrl={explorerUrl} />,
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
    }, [publicKey, refreshBalances]);

    const adminInitialise = useCallback(async () => {
        await handleTransaction(
            () => program.methods
                .initialize(new anchor.BN(100))
                .accounts({ authority: publicKey as PublicKey })
                .rpc(),
            "Initializing program...",
            "Program Initialized Successfully!",
            "Initialization Failed"
        );
    }, [program, publicKey, handleTransaction]);

    const adminDeposit = useCallback(async () => {
        if (!amount || amount <= 0) {
            toast.error("Please enter a valid deposit amount");
            return;
        }

        if (amount < ADMIN_CONFIG.minDeposit) {
            toast.error(`Minimum deposit amount is ${ADMIN_CONFIG.minDeposit} SOL`);
            return;
        }

        if (amount > ADMIN_CONFIG.maxDeposit) {
            toast.error(`Maximum deposit amount is ${ADMIN_CONFIG.maxDeposit} SOL`);
            return;
        }

        const balance = await connection.getBalance(publicKey as PublicKey);
        const balanceInSol = balance / 1e9;
        
        if (amount > balanceInSol) {
            toast.error(`Insufficient balance. You have ${balanceInSol.toFixed(4)} SOL`);
            return;
        }

        await handleTransaction(
            () => program.methods
                .deposit(new anchor.BN(amountInLamports))
                .accounts({ authority, player: publicKey as PublicKey })
                .rpc(),
            "Processing deposit...",
            "Deposit Successful!",
            "Deposit Failed"
        );

        setAmount(0);
    }, [amount, amountInLamports, connection, program, publicKey, handleTransaction]);

    const adminWithdraw = useCallback(async () => {
        await handleTransaction(
            () => program.methods
                .withdraw()
                .accounts({ authority })
                .rpc(),
            "Processing withdrawal...",
            "Withdrawal Successful!",
            "Withdrawal Failed"
        );
    }, [program, handleTransaction]);

    const adminConfig = useCallback(async () => {
        await handleTransaction(
            () => program.methods
                .config(apyInBasisPoints)
                .accounts({ authority })
                .rpc(),
            "Updating APY configuration...",
            "APY Configuration Updated!",
            "Failed to Update APY"
        );
    }, [program, apyInBasisPoints, handleTransaction]);

    // Effects
    useEffect(() => {
        refreshBalances();
    }, [publicKey, connection, refreshBalances]);

    return (
        <div className="main">
            <div className="main__block">
                <p className="main__block-title">{STAKE_NAME} Staking</p>
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
