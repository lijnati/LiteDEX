export const DEX_FACTORY_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Example from local deploy
export const TOKEN_A_ADDRESS = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
export const TOKEN_B_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

export const ERC20_ABI = [
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function decimals() view returns (uint8)",
    "function balanceOf(address) view returns (uint256)",
    "function approve(address, uint256) returns (bool)",
    "function allowance(address, address) view returns (uint256)",
    "event Transfer(address indexed from, address indexed to, uint256 value)"
];

export const DEX_ABI = [
    "function tokenA() view returns (address)",
    "function tokenB() view returns (address)",
    "function reserveA() view returns (uint256)",
    "function reserveB() view returns (uint256)",
    "function getReserves() view returns (uint256, uint256)",
    "function addLiquidity(uint256, uint256) returns (uint256)",
    "function removeLiquidity(uint256) returns (uint256, uint256)",
    "function swap(address, uint256, uint256) returns (uint256)",
    "function getAmountOut(address, uint256) view returns (uint256)",
    "function balanceOf(address) view returns (uint256)",
    "function totalSupply() view returns (uint256)"
];

export const FACTORY_ABI = [
    "function getPair(address, address) view returns (address)",
    "function createPair(address, address) returns (address)",
    "event PairCreated(address indexed token0, address indexed token1, address pair, uint256)"
];
