import { expect } from "chai";
import hre from "hardhat";

describe("LiteDEX System", function () {
    let factory, mockA, mockB, dex, token0, token1;
    let owner, user1;
    const initialMint = hre.ethers.parseEther("10000");

    beforeEach(async function () {
        [owner, user1] = await hre.ethers.getSigners();

        const DEXFactory = await hre.ethers.getContractFactory("DEXFactory");
        factory = await DEXFactory.deploy();

        const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
        mockA = await MockERC20.deploy("Token A", "TKNA");
        mockB = await MockERC20.deploy("Token B", "TKNB");

        await mockA.mint(owner.address, initialMint);
        await mockB.mint(owner.address, initialMint);
        await mockA.mint(user1.address, initialMint);
        await mockB.mint(user1.address, initialMint);

        await factory.createPair(await mockA.getAddress(), await mockB.getAddress());
        const pairAddress = await factory.getPair(await mockA.getAddress(), await mockB.getAddress());
        dex = await hre.ethers.getContractAt("SimpleDEX", pairAddress);

        const dexTokenA = await dex.tokenA();
        if (dexTokenA === (await mockA.getAddress())) {
            token0 = mockA;
            token1 = mockB;
        } else {
            token0 = mockB;
            token1 = mockA;
        }
    });

    describe("Liquidity", function () {
        it("Should add initial liquidity and mint LP tokens", async function () {
            const amount0 = hre.ethers.parseEther("100");
            const amount1 = hre.ethers.parseEther("200");

            await token0.approve(await dex.getAddress(), amount0);
            await token1.approve(await dex.getAddress(), amount1);

            await dex.addLiquidity(amount0, amount1);

            const reserve = await dex.getReserves();
            expect(reserve[0]).to.equal(amount0);
            expect(reserve[1]).to.equal(amount1);

            const lpBalance = await dex.balanceOf(owner.address);
            expect(lpBalance).to.be.gt(0);
        });

        it("Should remove liquidity correctly", async function () {
            const amount0 = hre.ethers.parseEther("100");
            const amount1 = hre.ethers.parseEther("200");
            await token0.approve(await dex.getAddress(), amount0);
            await token1.approve(await dex.getAddress(), amount1);
            await dex.addLiquidity(amount0, amount1);

            const lpBalance = await dex.balanceOf(owner.address);
            await dex.removeLiquidity(lpBalance);

            const reserve = await dex.getReserves();
            expect(reserve[0]).to.be.lt(hre.ethers.parseUnits("1", "gwei"));
        });
    });

    describe("Swap Math (0.3% Fee)", function () {
        it("Should execute swap with correct fee calculation", async function () {
            const poolAmount = hre.ethers.parseEther("1000");
            await token0.approve(await dex.getAddress(), poolAmount);
            await token1.approve(await dex.getAddress(), poolAmount);
            await dex.addLiquidity(poolAmount, poolAmount);

            const swapAmount = hre.ethers.parseEther("100");
            await token0.connect(user1).approve(await dex.getAddress(), swapAmount);

            // Call getAmountOut BEFORE the swap
            const expectedOut = await dex.getAmountOut(await token0.getAddress(), swapAmount);

            const balanceBefore = await token1.balanceOf(user1.address);
            await dex.connect(user1).swap(await token0.getAddress(), swapAmount, 0);
            const balanceAfter = await token1.balanceOf(user1.address);

            const actualOut = balanceAfter - balanceBefore;

            expect(actualOut).to.equal(expectedOut);
            expect(actualOut).to.be.closeTo(hre.ethers.parseEther("90.66"), hre.ethers.parseEther("0.01"));
        });

        it("Should fail if slippage is too high", async function () {
            const poolAmount = hre.ethers.parseEther("1000");
            await token0.approve(await dex.getAddress(), poolAmount);
            await token1.approve(await dex.getAddress(), poolAmount);
            await dex.addLiquidity(poolAmount, poolAmount);

            const swapAmount = hre.ethers.parseEther("100");
            await token0.connect(user1).approve(await dex.getAddress(), swapAmount);

            const expectedOut = await dex.getAmountOut(await token0.getAddress(), swapAmount);
            const minOut = expectedOut + 1n; // Asking for just 1 wei more than possible

            await expect(
                dex.connect(user1).swap(await token0.getAddress(), swapAmount, minOut)
            ).to.be.revertedWithCustomError(dex, "InsufficientOutputAmount");
        });
    });
});
