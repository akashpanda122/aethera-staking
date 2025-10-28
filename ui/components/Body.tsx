'use client'
import React, { useState, useEffect, useCallback, useMemo } from "react";
import { AccountId, ContractId, ContractExecuteTransaction, ContractFunctionParameters, Hbar, ContractCallQuery } from "@hashgraph/sdk";
import './body.css';
import { useHedera } from "./hooks/useHedera";
import { toast } from "sonner";
import { ToastContent } from "./ToastContent";

interface PlayerAccount {
    stakedAmount: number;
    stakedTime: number;
    durationTime: number;
    rewardAmount: number;
}

interface DurationButton {
    id: number;
    durName: string;
    durVal: number;
    isActive: boolean;
}

const STAKE_NAME = "HBAR";
const CONTRACT_ID = "0.0.YOUR_CONTRACT_ID"; // Replace with your deployed contract ID

const initialButtonsData: DurationButton[] = [
    { id: 0, durName: "7 days", durVal: 7, isActive: true },
    { id: 1, durName: "14 days", durVal: 14, isActive: false },
    { id: 2, durName: "30 days", durVal: 30, isActive: false },
    { id: 3, durName: "90 days", durVal: 90, isActive: false },
];

export const Body = () => {
    const { accountId, hashconnect, provider } = useHedera();
    
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
    const stakeAmountInTinybars = useMemo(() => stakeAmount * 1e8, [stakeAmount]); // HBAR to tinybars

    // Callbacks
    const getPlayerData = useCallback(async (player: string): Promise<PlayerAccount | null> => {
        if (!provider) return null;
        
        try {
            const query = new ContractCallQuery()
                .setContractId(ContractId.fromString(CONTRACT_ID))
                .setGas(100000)
                .setFunction("getPlayerData", new ContractFunctionParameters().addAddress(player));

            const result = await query.execute(provider);
            
            // Parse the contract response (adjust based on your contract's return structure)
            const stakedAmount = result.getUint256(0).toNumber();
            const stakedTime = result.getUint256(1).toNumber();
            const durationTime = result.getUint256(2).toNumber();
            const rewardAmount = result.getUint256(3).toNumber();

            return {
                stakedAmount,
                stakedTime,
                durationTime,
                rewardAmount
            };
        } catch (error) {
            console.error("Error fetching player data:", error);
            return null;
        }
    }, [provider]);

    const refreshBalances = useCallback(async () => {
        if (!accountId || !provider) return;
        
        try {
            // Get HBAR balance from Hedera
            const accountBalance = await provider.getAccountBalance(accountId);
            setBalance(accountBalance.hbars.toTinybars().toNumber() / 1e8);
            
            // Get player staking data from contract
            const player = await getPlayerData(accountId);
            setStakedAmount((player?.stakedAmount || 0) / 1e8);
            setStakedDuration(player?.durationTime || 0);
            setRewardAmount((player?.rewardAmount || 0) / 1e8);
            setStakeTime(player?.stakedTime?.toString() || '');
        } catch (error) {
            console.error("Error refreshing balances:", error);
        }
    }, [accountId, provider, getPlayerData]);

    const handleStakeAmountChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
        const amount = e.target.value;
        if (!amount || amount.match(/^\d{1,}(\.\d{0,8})?$/)) {
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

    const stake = useCallback(async () => {
        if (!accountId || !hashconnect || !provider) {
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
            async () => {
                const transaction = new ContractExecuteTransaction()
                    .setContractId(ContractId.fromString(CONTRACT_ID))
                    .setGas(300000)
                    .setPayableAmount(new Hbar(stakeAmount))
                    .setFunction(
                        "stake",
                        new ContractFunctionParameters()
                            .addUint256(stakeTypeInSeconds)
                    );

                const signer = hashconnect.getSigner(AccountId.fromString(accountId));
                const txResponse = await transaction.executeWithSigner(signer);
                const receipt = await txResponse.getReceiptWithSigner(signer);
                
                return txResponse.transactionId.toString();
            },
            "Staking...",
            "Staking Successful!",
            "Staking Failed"
        );

        setStakeAmount(0);
    }, [stakeAmount, balance, stakeTypeInSeconds, accountId, hashconnect, provider, handleTransaction]);

    const unstake = useCallback(async () => {
        if (!accountId || !hashconnect || !provider) {
            toast.warning("Please connect your wallet");
            return;
        }

        const player = await getPlayerData(accountId);
        if (!player || player.stakedAmount === 0) {
            toast.error("No staked amount found");
            return;
        }

        await handleTransaction(
            async () => {
                const transaction = new ContractExecuteTransaction()
                    .setContractId(ContractId.fromString(CONTRACT_ID))
                    .setGas(300000)
                    .setFunction("unstake");

                const signer = hashconnect.getSigner(AccountId.fromString(accountId));
                const txResponse = await transaction.executeWithSigner(signer);
                const receipt = await txResponse.getReceiptWithSigner(signer);
                
                return txResponse.transactionId.toString();
            },
            "Unstaking...",
            "Unstaking Successful!",
            "Unstaking Failed"
        );
    }, [accountId, hashconnect, provider, getPlayerData, handleTransaction]);

    const claimRewards = useCallback(async () => {
        if (!accountId || !hashconnect || !provider) {
            toast.warning("Please connect your wallet");
            return;
        }

        const player = await getPlayerData(accountId);
        if (!player || player.stakedAmount === 0) {
            toast.error("No rewards available to claim");
            return;
        }

        await handleTransaction(
            async () => {
                const transaction = new ContractExecuteTransaction()
                    .setContractId(ContractId.fromString(CONTRACT_ID))
                    .setGas(300000)
                    .setFunction("claimRewards");

                const signer = hashconnect.getSigner(AccountId.fromString(accountId));
                const txResponse = await transaction.executeWithSigner(signer);
                const receipt = await txResponse.getReceiptWithSigner(signer);
                
                return txResponse.transactionId.toString();
            },
            "Claiming rewards...",
            "Rewards Claimed Successfully!",
            "Failed to Claim Rewards"
        );
    }, [accountId, hashconnect, provider, getPlayerData, handleTransaction]);

    // Effects
    useEffect(() => {
        refreshBalances();
    }, [accountId, refreshBalances]);

    return (
        <div className="min-h-screen bg-gradient-to-br from-slate-950 via-purple-950 to-slate-950 p-6 md:p-12">
            <div className="max-w-7xl mx-auto">
                {/* Header Section */}
                <div className="mb-12 animate-fade-in">
                    <h1 className="text-4xl md:text-5xl font-bold bg-gradient-to-r from-purple-400 via-pink-400 to-purple-300 bg-clip-text text-transparent mb-2">{STAKE_NAME} Staking</h1>
                    <p className="text-slate-400 text-lg">Earn rewards on Hedera Hashgraph</p>
                </div>


                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Main Staking Card */}
                    <div className="lg:col-span-2 space-y-6">
                        {/* Balance Cards */}
                        <div className="grid grid-cols-2 gap-4">
                            <div className="backdrop-blur-xl bg-white/5 border border-purple-500/20 rounded-2xl p-6 hover:border-purple-400/40 transition-all duration-300 hover:bg-white/8">
                                <p className="text-slate-400 text-sm font-medium mb-2">Available Balance</p>
                                <p className="text-3xl font-bold text-purple-300">{balance.toFixed(4)}</p>
                                <p className="text-slate-500 text-xs mt-1">{STAKE_NAME}</p>
                            </div>
                            <div className="backdrop-blur-xl bg-white/5 border border-pink-500/20 rounded-2xl p-6 hover:border-pink-400/40 transition-all duration-300 hover:bg-white/8">
                                <p className="text-slate-400 text-sm font-medium mb-2">Staked Balance</p>
                                <p className="text-3xl font-bold text-pink-300">{stakedAmount.toFixed(4)}</p>
                                <p className="text-slate-500 text-xs mt-1">{STAKE_NAME}</p>
                            </div>
                        </div>

                        {/* Stake Input Section */}
                        <div className="backdrop-blur-xl bg-gradient-to-br from-white/8 to-white/5 border border-purple-500/30 rounded-2xl p-8 shadow-2xl hover:shadow-purple-500/10 transition-all duration-300">
                            <div className="mb-8">
                                <label className="block text-sm font-semibold text-slate-300 mb-3">Stake Amount</label>
                                <div className="relative">
                                    <input
                                        className="w-full bg-white/5 border border-purple-400/30 rounded-xl px-6 py-4 text-white text-lg placeholder-slate-500 focus:outline-none focus:border-purple-400/60 focus:bg-white/10 transition-all duration-300"
                                        value={stakeAmount}
                                        step="0.01"
                                        type="number"
                                        placeholder="Enter amount"
                                        onChange={handleStakeAmountChange}
                                    />
                                    <span className="absolute right-6 top-1/2 -translate-y-1/2 text-purple-400 font-semibold">
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
                                                ? "bg-gradient-to-r from-purple-500 to-pink-500 text-white shadow-lg shadow-purple-500/50"
                                                : "bg-white/5 border border-slate-600/50 text-slate-300 hover:border-purple-400/50 hover:bg-white/10"
                                            }`}
                                        >
                                            <span className="relative z-10">{button.durName}</span>
                                            {button.isActive && (
                                                <div className="absolute inset-0 bg-gradient-to-r from-purple-400 to-pink-400 opacity-0 group-hover:opacity-20 transition-opacity duration-300" />
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
                                    <div className="absolute inset-0 bg-gradient-to-r from-purple-500 to-purple-600 group-hover:from-purple-400 group-hover:to-purple-500 transition-all duration-300" />
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
                                    <div className="absolute inset-0 bg-gradient-to-r from-pink-500 to-pink-600 group-hover:from-pink-400 group-hover:to-pink-500 transition-all duration-300" />
                                    <div className="absolute inset-0 opacity-0 group-hover:opacity-20 bg-white transition-opacity duration-300" />
                                    <span className="relative z-10 flex items-center justify-center gap-2">
                                        {loading ? "..." : `Unstake ${STAKE_NAME}`}
                                    </span>
                                </button>
                            </div>
                        </div>
                    </div>
                
                    {/* Portfolio Card */}
                    <div className="backdrop-blur-xl bg-gradient-to-br from-white/8 to-white/5 border border-pink-500/30 rounded-2xl p-8 shadow-2xl hover:shadow-pink-500/10 transition-all duration-300 h-fit">
                        <h2 className="text-2xl font-bold text-pink-300 mb-6">Portfolio</h2>
                        
                        <div className="space-y-4">
                            {/* Portfolio Info Items */}
                            
                            <div className="bg-white/5 border border-purple-400/20 rounded-xl p-4 hover:bg-white/10 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                                    Stake Amount / Duration
                                </p>
                                <p className="text-xl font-bold text-purple-300">
                                    {stakedAmount} {STAKE_NAME}
                                </p>
                                <p className="text-sm text-slate-400 mt-1">{(stakedDuration || 0) / 86400} days</p>
                            </div>

                            <div className="bg-white/5 border border-pink-400/20 rounded-xl p-4 hover:bg-white/10 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Staking Time</p>
                                <p className="text-sm font-mono text-pink-300">
                                    {stakeTime ? new Date(Number(stakeTime) * 1000).toLocaleString() : "N/A"}
                                </p>
                            </div>

                            <div className="bg-white/5 border border-purple-400/20 rounded-xl p-4 hover:bg-white/10 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">APY</p>
                                <p className="text-2xl font-bold text-purple-300">50%</p>
                            </div>

                            <div className="bg-gradient-to-br from-purple-500/20 to-pink-500/20 border border-purple-400/30 rounded-xl p-4 hover:from-purple-500/30 hover:to-pink-500/30 transition-all duration-300">
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">Pending Rewards</p>
                                <p className="text-2xl font-bold text-transparent bg-gradient-to-r from-purple-300 to-pink-300 bg-clip-text">
                                    +{rewardAmount.toFixed(4)}
                                </p>
                                <p className="text-xs text-slate-400 mt-1">{STAKE_NAME}</p>
                            </div>

                            <button
                                className="w-full relative px-6 py-4 rounded-xl font-bold text-white overflow-hidden group disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-300 mt-6"
                                onClick={claimRewards}
                                disabled={loading}
                            >
                                <div className="absolute inset-0 bg-gradient-to-r from-purple-500 via-pink-500 to-purple-500 group-hover:from-purple-400 group-hover:via-pink-400 group-hover:to-purple-400 transition-all duration-300" />
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