const { ethers } = require("hardhat");
const { expect } = require("chai");


describe("MyMeme", function() {
    let memeToken, owner, user1, user2, pair, treasuryWallet, marketingWallet, totalSupply;
    before(async function() {
        [owner, user1, user2] = await ethers.getSigners();
        pair = await ethers.Wallet.createRandom().address;
        treasuryWallet = await ethers.Wallet.createRandom().address;
        marketingWallet = await ethers.Wallet.createRandom().address;
        totalSupply = ethers.parseEther("1000000000");


        //部署合约
        const MemeToken = await ethers.getContractFactory("MyMeme");
        memeToken = await MemeToken.deploy("MyMemeToken", "meme", totalSupply, pair, treasuryWallet, marketingWallet);
        await memeToken.waitForDeployment();
    })

    //测试部署和初始状态
    describe("deployment", function() {
        it('比对token部署者', async () => {
            expect(await memeToken.owner()).to.equal(owner.address);
        });
        it('对比name和symbol', async () => {
            expect(await memeToken.name()).to.equal("MyMemeToken");
            expect(await memeToken.symbol()).to.equal("meme");
        });
        it('对比totalSupply', async () => {
            const balance = await memeToken.balanceOf(owner.address);
            expect(balance).to.equal(totalSupply);
        })
        it('对比税率', async ()=> {
            expect(await memeToken.buyTax()).to.equal(10);
            expect(await memeToken.sellTax()).to.equal(15);
        });
        it('对比税收分配比例', async () => {
            expect(await memeToken.liquidityShare()).to.equal(50);
            expect(await memeToken.treasuryShare()).to.equal(30);
            expect(await memeToken.burnShare()).to.equal(20);
        });
    })

    //测试税收机制
    describe("Tax Mechanism", function() {
        it('模拟买入交易', async () => {
            //先给流动性池地址一些代币
            await memeToken.transfer(pair, ethers.parseEther("100000"));
            //给pair地址充值原生代币来支付gas
            const [owner] = await ethers.getSigners();
            await owner.sendTransaction({
                to: pair,
                value: ethers.parseEther("1.0") // 发送1 ETH足够支付大量交易的Gas
            });

            //模拟买入交易
            await expect(memeToken.connect(await ethers.getImpersonatedSigner(pair)).transfer(user1.address, ethers.parseEther("100")))
                .to.changeTokenBalances(
                    memeToken,
                    [pair,user1.address,treasuryWallet],
                    [
                        ethers.parseEther("-95"), //应该扣100的，但是其中10%的税收按照50%的配比流入来流动性池子
                        ethers.parseEther("90"), //买入税10%
                        ethers.parseEther("3"),  //税的30%到国库
                    ]
                );

        });

        it('模拟卖出交易', async () => {
            //先给user1转账一些代币
            await memeToken.transfer(user1.address, ethers.parseEther("1000"));

            //模拟卖出交易
            await expect(memeToken.connect(user1).transfer(pair, ethers.parseEther("100")))
                .to.changeTokenBalances(
                    memeToken,
                    [user1.address, pair, treasuryWallet],
                    [
                        ethers.parseEther("-100"),
                        ethers.parseEther("92.5"), //卖出税是15%，其中50%到流动性，那么15的50%是7.5
                        ethers.parseEther("4.5"), //国库增加税的30%
                    ]
                )
        });
    })

    describe("transactions limits", function() {
        it('检查单笔交易限额', async () => {
            //先给user1转账一些代币
            await memeToken.transfer(user1.address, ethers.parseEther("10000"));
            //计算最大的交易限额
            const maxTxAmount = await memeToken.maxTransactionAmount();
            //尝试发送超过最大限额的交易
            expect(memeToken.connect(user1).transfer(user2.address, maxTxAmount + ethers.parseEther("1")))
                .to.be.revertedWith("amount exceeds max transaction limit");
        });

        it('检查钱包持有量限制',async () => {
            //查看最大的钱包持有量
            const maxWalletAmount = await memeToken.maxWalletSize();
            console.log("最大钱包限额:", maxWalletAmount);
            //先给user1转最大限额
            const maxTxAmount = await memeToken.maxTransactionAmount();
            await memeToken.transfer(user1.address, maxTxAmount);
            //再次转账会失败
            const balance = await memeToken.balanceOf(user1.address);
            console.log("当前余额：",balance);
            expect(await memeToken.transfer(user1.address, ethers.parseEther("1")))
            .to.be.revertedWith("exceeds max wallet size");
        });

        it('检查每日交易次数限制', async () => {
            //先给user1转一些代币
            await memeToken.transfer(user1.address, ethers.parseEther("10000"));
            //获取交易限额
            const maxDailyTx = await memeToken.maxDailyTransactions();
            //发送maxDailyTx次数的交易
            for (let i = 0; i < maxDailyTx.length; i++) {
                await memeToken.connect(user1).transfer(user2.address, ethers.parseEther("1"));
            }
            //maxDailyTx数量的次数交易完成后，再次交易会失败
            expect(await memeToken.connect(user1).transfer(user2.address, ethers.parseEther("1")))
                .to.be.revertedWith("exceed max daily transaction");
        });

        it('检查交易次数满了之后过了一天才可以再次交易', async () => {
            //先给user1转一些代币
            await memeToken.transfer(user1.address, ethers.parseEther("10000"));
            //获取交易限额
            const maxDailyTx = await memeToken.maxDailyTransactions();
            //发送maxDailyTx次数的交易
            for (let i = 0; i < maxDailyTx.length; i++) {
                await memeToken.connect(user1).transfer(user2.address, ethers.parseEther("1"));
            }

            //过去一天
            await ethers.provider.send("evm_increaseTime", [86401]);
            await ethers.provider.send("evm_mine");

            //maxDailyTx数量的次数交易完成后，再次交易会失败
            expect(await memeToken.connect(user1).transfer(user2.address, ethers.parseEther("1")))
                .to.not.be.reverted;
        });
    })

    //测试权限限制
    describe("access control", function() {
        it('正常更新税率', async () => {
            await expect(memeToken.updateTaxRates(5, 8))
                .to.emit(memeToken, "TaxRatesUpdated")
                .withArgs(5, 8);
            expect(await memeToken.buyTax()).to.equal(5);
            expect(await memeToken.sellTax()).to.equal(8);
        });

        it('非管理者进行更新', async () => {
            expect(memeToken.connect(user1).updateTaxRates(5, 8))
                .to.be.revertedWithCustomError(memeToken, "OwnableUnauthorizedAccount")
                .withArgs(user1.address);
        });

        it('正常更新税收分配比例', async () => {
            await expect(memeToken.updateTaxShare(40, 40, 20))
                .to.emit(memeToken, "TaxDistributionUpdated")
                .withArgs(40, 40, 20);
            expect(await memeToken.liquidityShare()).to.equal(40);
            expect(await memeToken.treasuryShare()).to.equal(40);
            expect(await memeToken.burnShare()).to.equal(20);
        });

        it('税收比例不是100%',async () => {
            await expect(memeToken.updateTaxShare(40, 40, 30)).to.be.revertedWith("Distribution must sum to 100");
        });

        it('正常更新交易限制', async () => {
            await expect(memeToken.updateTransactionLimits(10**7, 20**7, 5))
                .to.emit(memeToken, "TransactionLimitsUpdated")
                .withArgs(10**7, 20**7, 5);
            expect(await memeToken.maxTransactionAmount()).to.equal(10**7);
            expect(await memeToken.maxWalletSize()).to.equal(20**7);
            expect(await memeToken.maxDailyTransactions()).to.equal(5);
        });

        it('更新钱包地址的状态(税收排除和黑名单)', async () => {
            await expect(memeToken.updateWalletStatus(user1.address, true, false))
                .to.emit(memeToken, "WalletStatusUpdated")
                .withArgs(user1.address, true, false);
            expect(await memeToken.isExcludedFromTax(user1.address)).to.equal(true);
            expect(await memeToken.isBlackedListed(user1.address)).to.equal(false);
        });
    })

    //测试流动性功能
    describe("test liquidity function", function() {
        it('流动性添加测试',async () => {
            await expect(memeToken.updateTransactionLimits(ethers.parseEther("100"), ethers.parseEther("200"), 5))
                .to.emit(memeToken, "TransactionLimitsUpdated")
                .withArgs(ethers.parseEther("100"), ethers.parseEther("200"), 5);

            const tokenAmount = ethers.parseEther("50");
            const ethAmount = ethers.parseEther("1");

            // 批准合约使用代币
            await memeToken.connect(user1).approve(memeToken.target, tokenAmount);

            // 记录用户1初始余额
            const initialBalance = await memeToken.balanceOf(user1.address);
            console.log("initial balance: ", initialBalance);

            // 执行添加流动性操作
            await expect(memeToken.connect(user1).addLiquidity(tokenAmount, {
                value: ethAmount
            }))
                .to.changeTokenBalance(
                    memeToken,
                    user1.address,
                    ethers.parseEther("-50") // 用户余额减少100
                );
        });
    })

    describe("test emergency withdrawn", function() {
        it("紧急提款", async () => {
            // 1. 先给addr1转一些代币（用于调用addLiquidity）
            const tokenAmount = ethers.parseEther("50");
            await memeToken.transfer(user1.address, tokenAmount);

            // 2. 通过addLiquidity函数向合约存入ETH（而非直接转账）
            // addLiquidity是payable函数，能合法向合约转入ETH
            await memeToken.connect(user1).addLiquidity(
                tokenAmount, // 代币数量
                { value: ethers.parseEther("1") } // 存入1 ETH
            );

            // 验证合约已收到ETH
            expect(await ethers.provider.getBalance(memeToken.getAddress())).to.equal(ethers.parseEther("2"));

            // 3. 记录所有者初始余额
            const ownerInitialBalance = await ethers.provider.getBalance(owner.address);
            console.log("ownerInitialBalance: ", ownerInitialBalance);

            // 4. 紧急提款（仅所有者可调用）
            const tx = await memeToken.emergencyWithdrawn();
            await tx.wait();

            // 6. 验证合约余额归零
            expect(await ethers.provider.getBalance(memeToken.getAddress())).to.equal(0);
        });
    })
})