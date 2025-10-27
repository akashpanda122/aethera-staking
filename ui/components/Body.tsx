'use client'
import React, { useState, useEffect, useCallback, useMemo } from "react";
import { PublicKey } from '@solana/web3.js';
import { useConnection } from '@solana/wallet-adapter-react';
import './body.css';
import { useProgram } from "./hooks/useProgram";
import * as anchor from "@coral-xyz/anchor";
import { toast } from "sonner";
import { ToastContent } from "./ToastContent";

interface PlayerAccount {
    stakedAmount: number;
    stakedTime: anchor.BN;
    durationTime: anchor.BN;
    rewardAmount: anchor.BN;
}

interface DurationButton {
    id: number;
    durName: string;
    durVal: number;
    isActive: boolean;
}

const STAKE_NAME = "SOL";
const authority = new PublicKey("7ivunejTCC3g6gWqYZqVRpthdyj29vPmVas5YcCy5Yh8");

const initialButtonsData: DurationButton[] = [
    { id: 0, durName: "7 days", durVal: 7, isActive: true },
    { id: 1, durName: "14 days", durVal: 14, isActive: false },
    { id: 2, durName: "30 days", durVal: 30, isActive: false },
    { id: 3, durName: "90 days", durVal: 90, isActive: false },
];

export const Body = () => {
    const { program, publicKey } = useProgram();
    const { connection } = useConnection();
    
    // State management
    const [buttons, setButtons] = useState<DurationButton[]>(initialButtonsData);
    const [balance, setBalance] = useState<number>(0);
    const [loading, setLoading] = useState<boolean>(false);
    const [stakeAmount, setStakeAmount] = useState<number>(0);
    const [stakedAmount, setStakedAmount] = useState<number>(0);
    const [stakeType, setStakeType] = useState<number>(7);
    const [stakeTime, setStakeTime] = useState<string>('');
    const [rewardAmount, setRewardAmount] = useState<number>(0);
    const [stakedDuration, setStakedDuration] = useState<number>(0);

    // Memoized values
    const stakeTypeInSeconds = useMemo(() => stakeType * 86400, [stakeType]);
    const stakeAmountInLamports = useMemo(() => stakeAmount * 1e9, [stakeAmount]);

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
            setStakedDuration(Number(player?.durationTime || 0));
            setRewardAmount(Number(player?.rewardAmount || 0) / 1e9);
            setStakeTime(player?.stakedTime.toString() || '');
        } catch (error) {
            console.error("Error refreshing balances:", error);
        }
    }, [publicKey, connection, getPlayerData]);

    const handleStakeAmountChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const amount = e.target.value;
        if (!amount || amount.match(/^\d{1,}(\.\d{0,2})?$/)) {
            setStakeAmount(Number(amount));
        }
    }, []);

    const handleDurationChange = useCallback((id: number) => {
        setButtons(prevButtons => prevButtons.map(button => ({
            ...button,
            isActive: id === button.id
        })));
        setStakeType(buttons.find(btn => btn.id === id)?.durVal || 7);
    }, [buttons]);

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

    const stake = useCallback(async () => {
        if (!publicKey) {
            toast.warning("Please connect your wallet");
            return;
        }

        if (stakeAmount <= 0) {
            toast.error("Please enter a valid amount");
            return;
        }

        if (stakeAmount > balance) {
            toast.error("Insufficient balance");
            return;
        }

        await handleTransaction(
            () => program.methods
                .solStake(new anchor.BN(stakeAmountInLamports), new anchor.BN(stakeTypeInSeconds))
                .accounts({ authority, player: publicKey as PublicKey })
                .rpc(),
            "Staking...",
            "Staking Successful!",
            "Staking Failed"
        );

        setStakeAmount(0);
    }, [stakeAmount, balance, stakeAmountInLamports, stakeTypeInSeconds, program, publicKey, handleTransaction]);

    const unstake = useCallback(async () => {
        if (!publicKey) {
            toast.warning("Please connect your wallet");
            return;
        }

        const player = await getPlayerData(publicKey);
        if (!player || player.stakedAmount === 0) {
            toast.error("No staked amount found");
            return;
        }

        await handleTransaction(
            () => program.methods
                .solUnstake()
                .accounts({ authority, player: publicKey as PublicKey })
                .rpc(),
            "Unstaking...",
            "Unstaking Successful!",
            "Unstaking Failed"
        );
    }, [publicKey, getPlayerData, program, handleTransaction]);

    const claimRewards = useCallback(async () => {
        if (!publicKey) {
            toast.warning("Please connect your wallet");
            return;
        }

        const player = await getPlayerData(publicKey);
        if (!player || player.stakedAmount === 0) {
            toast.error("No rewards available to claim");
            return;
        }

        await handleTransaction(
            () => program.methods
                .claimRewards()
                .accounts({ authority, player: publicKey as PublicKey })
                .rpc(),
            "Claiming rewards...",
            "Rewards Claimed Successfully!",
            "Failed to Claim Rewards"
        );
    }, [publicKey, getPlayerData, program, handleTransaction]);

    // Effects
    useEffect(() => {
        refreshBalances();
    }, [publicKey, connection, refreshBalances]);

    return (
        <div className="min-h-screen bg-gradient-to-br from-slate-950 via-emerald-950 to-slate-950 p-6 md:p-12">
            <div className="max-w-7xl mx-auto">
                {/* Header Section */}
                <div className="mb-12 animate-fade-in">
                    <h1 className="text-4xl md:text-5xl font-bold bg-gradient-to-r from-emerald-400 via-cyan-400 to-emerald-300 bg-clip-text text-transparent mb-2">{STAKE_NAME} Staking</h1>
                    <p className="text-slate-400 text-lg">Earn rewards while supporting green energy initiatives</p>
                </div>


                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Main Staking Card */}
                    <div className="lg:col-span-2 space-y-6">
                        {/* Balance Cards */}
                        <div className="grid grid-cols-2 gap-4">
                            <div className="backdrop-blur-xl bg-white/5 border border-emerald-500/20 rounded-2xl p-6 hover:border-emerald-400/40 transition-all duration-300 hover:bg-white/8">
                                <p className="text-slate-400 text-sm font-medium mb-2">Available Balance</p>
                                <p className="text-3xl font-bold text-emerald-300">{balance.toFixed(4)}</p>
                                <p className="text-slate-500 text-xs mt-1">{STAKE_NAME}</p>
                            </div>
                            <div className="backdrop-blur-xl bg-white/5 border border-cyan-500/20 rounded-2xl p-6 hover:border-cyan-400/40 transition-all duration-300 hover:bg-white/8">
                                <p className="text-slate-400 text-sm font-medium mb-2">Staked Balance</p>
                                <p className="text-3xl font-bold text-cyan-300">{stakedAmount.toFixed(4)}</p>
                                <p className="text-slate-500 text-xs mt-1">{STAKE_NAME}</p>
                            </div>
                        </div>

                        {/* Stake Input Section */}
                        <div className="backdrop-blur-xl bg-gradient-to-br from-white/8 to-white/5 border border-emerald-500/30 rounded-2xl p-8 shadow-2xl hover:shadow-emerald-500/10 transition-all duration-300">
                            <div className="mb-8">
                                <label className="block text-sm font-semibold text-slate-300 mb-3">Stake Amount</label>
                                <div className="relative">
                                    <input
                                        className="w-full bg-white/5 border border-emerald-400/30 rounded-xl px-6 py-4 text-white text-lg placeholder-slate-500 focus:outline-none focus:border-emerald-400/60 focus:bg-white/10 transition-all duration-300"
                                        value={stakeAmount}
                                        step="0.01"
                                        type="number"
                                        placeholder="Enter amount"
                                        onChange={handleStakeAmountChange}
                                    />
                                    <span className="absolute right-6 top-1/2 -translate-y-1/2 text-emerald-400 font-semibold">
                                        {STAKE_NAME}
                                    </span>
                                </div>
                            </div>

                            {/* Duration Selection */}
                            <div className="mb-8">
                                <label className="block text-sm font-semibold text-slate-300 mb-4">Staking Duration</label>
                                <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                                    {buttons.map(button => (
                                        <button
                                            key={button.id}
                                            onClick={() => handleDurationChange(button.id)}
                                            className={`relative px-4 py-3 rounded-xl font-semibold transition-all duration-300 overflow-hidden group ${
                                            button.isActive
                                                ? "bg-gradient-to-r from-emerald-500 to-cyan-500 text-white shadow-lg shadow-emerald-500/50"
                                                : "bg-white/5 border border-slate-600/50 text-slate-300 hover:border-emerald-400/50 hover:bg-white/10"
                                            }`}
                                        >
                                            <span className="relative z-10">{button.durName}</span>
                                            {button.isActive && (
                                                <div className="absolute inset-0 bg-gradient-to-r from-emerald-400 to-cyan-400 opacity-0 group-hover:opacity-20 transition-opacity duration-300" />
                                            )}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Action Buttons */}
                            <div className="grid grid-cols-2 gap-4">
                                
                                <button
                                    className="relative px-6 py-4 rounded-xl font-bold text-white overflow-hidden group disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300"
                                    onClick={stake}
                                    disabled={loading}
                                >
                                    <div className="absolute inset-0 bg-gradient-to-r from-emerald-500 to-emerald-600 group-hover:from-emerald-400 group-hover:to-emerald-500 transition-all duration-300" />
                                    <div className="absolute inset-0 opacity-0 group-hover:opacity-20 bg-white transition-opacity duration-300" />
                                    <span className="relative z-10 flex items-center justify-center gap-2">
                                        {loading ? "..." : `Stake ${STAKE_NAME}`}
                                    </span>
                                </button>

                                <button
                                    className="relative px-6 py-4 rounded-xl font-bold text-white overflow-hidden group disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300"
                                    onClick={unstake}
                                    disabled={loading}
                                >
                                    <div className="absolute inset-0 bg-gradient-to-r from-cyan-500 to-cyan-600 group-hover:from-cyan-400 group-hover:to-cyan-500 transition-all duration-300" />
                                    <div className="absolute inset-0 opacity-0 group-hover:opacity-20 bg-white transition-opacity duration-300" />
                                    <span className="relative z-10 flex items-center justify-center gap-2">
                                        {loading ? "..." : `Unstake ${STAKE_NAME}`}
                                    </span>
                                </button>
                            </div>
                        </div>
                    </div>
                
                    {/* Portfolio Card */}
                    <div className="backdrop-blur-xl bg-gradient-to-br from-white/8 to-white/5 border border-cyan-500/30 rounded-2xl p-8 shadow-2xl hover:shadow-cyan-500/10 transition-all duration-300 h-fit">
                        <h2 className="text-2xl font-bold text-cyan-300 mb-6">Portfolio</h2>
                        
                        <div className="space-y-4">
                            {/* Portfolio Info Items */}
                            
                            <div className="bg-white/5 border border-emerald-400/20 rounded-xl p-4 hover:bg-white/10 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                                    Stake Amount / Duration
                                </p>
                                <p className="text-xl font-bold text-emerald-300">
                                    {stakedAmount} {STAKE_NAME}
                                </p>
                                <p className="text-sm text-slate-400 mt-1">{(stakedDuration || 0) / 86400} days</p>
                            </div>

                            <div className="bg-white/5 border border-cyan-400/20 rounded-xl p-4 hover:bg-white/10 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Staking Time</p>
                                <p className="text-sm font-mono text-cyan-300">
                                    {stakeTime ? new Date(Number(stakeTime) * 1000).toLocaleString() : "N/A"}
                                </p>
                            </div>

                            <div className="bg-white/5 border border-emerald-400/20 rounded-xl p-4 hover:bg-white/10 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">APY</p>
                                <p className="text-2xl font-bold text-emerald-300">50%</p>
                            </div>

                            <div className="bg-gradient-to-br from-emerald-500/20 to-cyan-500/20 border border-emerald-400/30 rounded-xl p-4 hover:from-emerald-500/30 hover:to-cyan-500/30 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Pending Rewards</p>
                                <p className="text-2xl font-bold text-transparent bg-gradient-to-r from-emerald-300 to-cyan-300 bg-clip-text">
                                    +{rewardAmount.toFixed(4)}
                                </p>
                                <p className="text-xs text-slate-400 mt-1">{STAKE_NAME}</p>
                            </div>

                            <button
                                className="w-full relative px-6 py-4 rounded-xl font-bold text-white overflow-hidden group disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 mt-6"
                                onClick={claimRewards}
                                disabled={loading}
                            >
                                <div className="absolute inset-0 bg-gradient-to-r from-emerald-500 via-cyan-500 to-emerald-500 group-hover:from-emerald-400 group-hover:via-cyan-400 group-hover:to-emerald-400 transition-all duration-300" />
                                <div className="absolute inset-0 opacity-0 group-hover:opacity-30 bg-white transition-opacity duration-300" />
                                <span className="relative z-10">{loading ? "Processing..." : "Claim Rewards"}</span>
                            </button>

                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};