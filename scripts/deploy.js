import hre from "hardhat";

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    // 1. Deploy Mock Token A
    const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
    const tokenA = await MockERC20.deploy("Token A", "TKNA");
    await tokenA.waitForDeployment();
    console.log("Token A deployed to:", await tokenA.getAddress());

    // 2. Deploy Mock Token B
    const tokenB = await MockERC20.deploy("Token B", "TKNB");
    await tokenB.waitForDeployment();
    console.log("Token B deployed to:", await tokenB.getAddress());

    // 3. Deploy SimpleDEX
    const SimpleDEX = await hre.ethers.getContractFactory("SimpleDEX");
    const dex = await SimpleDEX.deploy(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        "LiteDEX LP Token",
        "LDX-LP"
    );
    await dex.waitForDeployment();
    console.log("SimpleDEX deployed to:", await dex.getAddress());

    // 4. Set up initial liquidity
    const amountA = hre.ethers.parseEther("100");
    const amountB = hre.ethers.parseEther("200");

    console.log("Minting tokens...");
    await tokenA.mint(deployer.address, amountA);
    await tokenB.mint(deployer.address, amountB);

    console.log("Approving DEX...");
    await tokenA.approve(await dex.getAddress(), amountA);
    await tokenB.approve(await dex.getAddress(), amountB);

    console.log("Adding liquidity...");
    await dex.addLiquidity(amountA, amountB);
    console.log("Liquidity added successfully!");

    const reserves = await dex.getReserves();
    console.log(`Pool Reserves: TokenA: ${hre.ethers.formatEther(reserves[0])}, TokenB: ${hre.ethers.formatEther(reserves[1])}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
