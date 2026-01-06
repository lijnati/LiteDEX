"use client";

import { useState, useEffect, useCallback } from "react";
import { ethers } from "ethers";
import {
  ArrowDown,
  Wallet,
  RefreshCw,
  Settings,
  Plus,
  Minus,
  ExternalLink,
  ChevronDown
} from "lucide-react";
import {
  DEX_ABI,
  ERC20_ABI,
  FACTORY_ABI,
  DEX_FACTORY_ADDRESS,
  TOKEN_A_ADDRESS,
  TOKEN_B_ADDRESS
} from "./constants";

export default function Home() {
  const [account, setAccount] = useState("");
  const [provider, setProvider] = useState(null);
  const [activeTab, setActiveTab] = useState("swap");
  const [loading, setLoading] = useState(false);

  // Swap States
  const [fromAmount, setFromAmount] = useState("");
  const [toAmount, setToAmount] = useState("");
  const [fromToken, setFromToken] = useState({ symbol: "TKNA", address: TOKEN_A_ADDRESS });
  const [toToken, setToToken] = useState({ symbol: "TKNB", address: TOKEN_B_ADDRESS });

  // Liquidity States
  const [liqAmountA, setLiqAmountA] = useState("");
  const [liqAmountB, setLiqAmountB] = useState("");
  const [lpBalance, setLpBalance] = useState("0");

  // DEX Info
  const [reserves, setReserves] = useState({ a: "0", b: "0" });
  const [pairAddress, setPairAddress] = useState("");

  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
        setAccount(accounts[0]);
        const tempProvider = new ethers.BrowserProvider(window.ethereum);
        setProvider(tempProvider);
      } catch (err) {
        console.error("User denied account access");
      }
    } else {
      alert("Please install MetaMask!");
    }
  };

  const fetchPair = useCallback(async () => {
    if (!provider) return;
    try {
      const signer = await provider.getSigner();
      const factory = new ethers.Contract(DEX_FACTORY_ADDRESS, FACTORY_ABI, signer);
      const pair = await factory.getPair(TOKEN_A_ADDRESS, TOKEN_B_ADDRESS);
      setPairAddress(pair);

      if (pair !== ethers.ZeroAddress) {
        const dex = new ethers.Contract(pair, DEX_ABI, signer);
        const [resA, resB] = await dex.getReserves();
        setReserves({
          a: ethers.formatEther(resA),
          b: ethers.formatEther(resB)
        });

        if (account) {
          const bal = await dex.balanceOf(account);
          setLpBalance(ethers.formatEther(bal));
        }
      }
    } catch (err) {
      console.error("Error fetching pair:", err);
    }
  }, [provider, account]);

  useEffect(() => {
    fetchPair();
  }, [fetchPair]);

  const handleSwap = async () => {
    if (!pairAddress || !fromAmount) return;
    setLoading(true);
    try {
      const signer = await provider.getSigner();
      const dex = new ethers.Contract(pairAddress, DEX_ABI, signer);
      const tokenIn = new ethers.Contract(fromToken.address, ERC20_ABI, signer);

      const amountIn = ethers.parseEther(fromAmount);

      // Approve if needed
      const allowance = await tokenIn.allowance(account, pairAddress);
      if (allowance < amountIn) {
        const txApprove = await tokenIn.approve(pairAddress, amountIn);
        await txApprove.wait();
      }

      const txSwap = await dex.swap(fromToken.address, amountIn, 0); // 0 minOut for demo
      await txSwap.wait();

      alert("Swap successful!");
      fetchPair();
      setFromAmount("");
      setToAmount("");
    } catch (err) {
      console.error("Swap failed:", err);
      alert("Swap failed. See console.");
    }
    setLoading(false);
  };

  const handleAddLiquidity = async () => {
    if (!pairAddress || !liqAmountA || !liqAmountB) return;
    setLoading(true);
    try {
      const signer = await provider.getSigner();
      const dex = new ethers.Contract(pairAddress, DEX_ABI, signer);
      const tokenA = new ethers.Contract(TOKEN_A_ADDRESS, ERC20_ABI, signer);
      const tokenB = new ethers.Contract(TOKEN_B_ADDRESS, ERC20_ABI, signer);

      const valA = ethers.parseEther(liqAmountA);
      const valB = ethers.parseEther(liqAmountB);

      // Approve Token A
      const allowanceA = await tokenA.allowance(account, pairAddress);
      if (allowanceA < valA) {
        const txA = await tokenA.approve(pairAddress, valA);
        await txA.wait();
      }

      // Approve Token B
      const allowanceB = await tokenB.allowance(account, pairAddress);
      if (allowanceB < valB) {
        const txB = await tokenB.approve(pairAddress, valB);
        await txB.wait();
      }

      const txAdd = await dex.addLiquidity(valA, valB);
      await txAdd.wait();

      alert("Liquidity added successfully!");
      fetchPair();
      setLiqAmountA("");
      setLiqAmountB("");
    } catch (err) {
      console.error("Add liquidity failed:", err);
      alert("Failed to add liquidity.");
    }
    setLoading(false);
  };

  const calculateOutput = async (val) => {
    setFromAmount(val);
    if (!val || val === "0" || !pairAddress) {
      setToAmount("");
      return;
    }
    try {
      const dex = new ethers.Contract(pairAddress, DEX_ABI, provider);
      const amountIn = ethers.parseEther(val);
      const amountOut = await dex.getAmountOut(fromToken.address, amountIn);
      setToAmount(ethers.formatEther(amountOut));
    } catch (err) {
      console.error("Error calculating output:", err);
    }
  };

  return (
    <div className="container" style={{ padding: "20px", display: "flex", flexDirection: "column", alignItems: "center" }}>
      {/* Header */}
      <nav style={{ width: "100%", maxWidth: "1200px", display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "60px" }}>
        <h1 className="gradient-text" style={{ fontSize: "28px", fontWeight: "800", letterSpacing: "-1px" }}>LiteDEX</h1>
        {account ? (
          <div className="glass-card" style={{ padding: "8px 16px", borderRadius: "12px", border: "1px solid var(--accent-primary)" }}>
            <span style={{ fontSize: "14px", fontWeight: "500" }}>{account.slice(0, 6)}...{account.slice(-4)}</span>
          </div>
        ) : (
          <button className="btn-primary" onClick={connectWallet} style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <Wallet size={18} /> Connect Wallet
          </button>
        )}
      </nav>

      {/* Main UI */}
      <main className="glass-card" style={{ width: "100%", maxWidth: "460px", padding: "8px" }}>
        {/* Tabs */}
        <div style={{ display: "flex", gap: "4px", padding: "4px", marginBottom: "12px" }}>
          <button
            className={`tab-btn ${activeTab === "swap" ? "active" : ""}`}
            onClick={() => setActiveTab("swap")}
            style={{ flex: 1 }}
          >
            Swap
          </button>
          <button
            className={`tab-btn ${activeTab === "pool" ? "active" : ""}`}
            onClick={() => setActiveTab("pool")}
            style={{ flex: 1 }}
          >
            Pool
          </button>
        </div>

        <div style={{ padding: "12px" }}>
          {activeTab === "swap" ? (
            <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
              {/* From Token */}
              <div className="input-group">
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                  <span style={{ fontSize: "14px", color: "var(--text-muted)" }}>From</span>
                  <span style={{ fontSize: "14px", color: "var(--text-muted)" }}>Balance: 0.0</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                  <input
                    placeholder="0.0"
                    type="number"
                    value={fromAmount}
                    onChange={(e) => calculateOutput(e.target.value)}
                  />
                  <div style={{ display: "flex", alignItems: "center", gap: "6px", background: "rgba(255,255,255,0.1)", padding: "4px 10px", borderRadius: "12px", cursor: "pointer" }}>
                    <span style={{ fontWeight: "600" }}>{fromToken.symbol}</span>
                    <ChevronDown size={14} />
                  </div>
                </div>
              </div>

              {/* Arrow */}
              <div style={{ display: "flex", justifyContent: "center", margin: "-12px 0", zIndex: 2 }}>
                <div className="glass-card" style={{ borderRadius: "10px", padding: "6px", border: "4px solid #171b22" }}>
                  <ArrowDown size={16} color="var(--accent-primary)" />
                </div>
              </div>

              {/* To Token */}
              <div className="input-group">
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                  <span style={{ fontSize: "14px", color: "var(--text-muted)" }}>To</span>
                  <span style={{ fontSize: "14px", color: "var(--text-muted)" }}>Balance: 0.0</span>
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                  <input placeholder="0.0" type="number" readOnly value={toAmount} />
                  <div style={{ display: "flex", alignItems: "center", gap: "6px", background: "rgba(255,255,255,0.1)", padding: "4px 10px", borderRadius: "12px", cursor: "pointer" }}>
                    <span style={{ fontWeight: "600" }}>{toToken.symbol}</span>
                    <ChevronDown size={14} />
                  </div>
                </div>
              </div>

              {/* Rate & Info */}
              {pairAddress && (
                <div style={{ padding: "12px", fontSize: "13px", color: "var(--text-muted)" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "4px" }}>
                    <span>Exchange Rate</span>
                    <span>1 {fromToken.symbol} = {(reserves.b / reserves.a).toFixed(4)} {toToken.symbol}</span>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between" }}>
                    <span>Slippage Tolerance</span>
                    <span>0.5%</span>
                  </div>
                </div>
              )}

              <button
                className="btn-primary"
                style={{ marginTop: "12px", width: "100%", fontSize: "18px", padding: "16px" }}
                onClick={handleSwap}
                disabled={loading || !fromAmount}
              >
                {loading ? <RefreshCw className="animate-spin" /> : (account ? "Swap" : "Connect Wallet")}
              </button>
            </div>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: "12px", padding: "12px" }}>
              <div style={{ background: "var(--glass-bg)", padding: "16px", borderRadius: "16px", marginBottom: "8px" }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                  <span style={{ fontSize: "14px", color: "var(--text-muted)" }}>Your Position</span>
                  <span style={{ fontSize: "14px", fontWeight: "600" }}>{parseFloat(lpBalance).toFixed(6)} LP</span>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", fontSize: "13px" }}>
                  <span>Pooled {fromToken.symbol}</span>
                  <span>{((parseFloat(lpBalance) / (parseFloat(lpBalance) || 1)) * reserves.a || 0).toFixed(4)}</span>
                </div>
              </div>

              <div className="input-group">
                <span style={{ fontSize: "12px", color: "var(--text-muted)" }}>{fromToken.symbol} Amount</span>
                <input
                  placeholder="0.0"
                  type="number"
                  value={liqAmountA}
                  onChange={(e) => setLiqAmountA(e.target.value)}
                  style={{ fontSize: "20px" }}
                />
              </div>

              <div style={{ display: "flex", justifyContent: "center", margin: "-8px 0" }}>
                <Plus size={16} color="var(--text-muted)" />
              </div>

              <div className="input-group">
                <span style={{ fontSize: "12px", color: "var(--text-muted)" }}>{toToken.symbol} Amount</span>
                <input
                  placeholder="0.0"
                  type="number"
                  value={liqAmountB}
                  onChange={(e) => setLiqAmountB(e.target.value)}
                  style={{ fontSize: "20px" }}
                />
              </div>

              <button
                className="btn-primary"
                style={{ marginTop: "12px", width: "100%", padding: "16px" }}
                onClick={handleAddLiquidity}
                disabled={loading || !liqAmountA || !liqAmountB}
              >
                {loading ? <RefreshCw className="animate-spin" /> : (account ? "Supply Liquidity" : "Connect Wallet")}
              </button>
            </div>
          )}
        </div>
      </main>

      {/* Footer Info */}
      <div style={{ marginTop: "40px", display: "flex", gap: "24px", color: "var(--text-muted)", fontSize: "14px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "6px" }}>
          <div style={{ width: "8px", height: "8px", borderRadius: "50%", background: "#4ade80" }}></div>
          Local Hardhat Node
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: "4px", cursor: "pointer" }}>
          View on Explorer <ExternalLink size={14} />
        </div>
      </div>

      <style jsx global>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        .animate-spin {
          animation: spin 1s linear infinite;
        }
      `}</style>
    </div>
  );
}
