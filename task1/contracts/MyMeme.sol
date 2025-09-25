// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract MyMeme is ERC20, Ownable, ReentrancyGuard {
    // 税率设置(百分比设置，实际计算时除以100)
    uint256 public buyTax; //购买税
    uint256 public sellTax; //售卖税

    // 税收分配比例(总税收的百分比)
    uint256 public liquidityShare;  //流动性占比
    uint256 public treasuryShare;   //国库占比
    uint256 public burnShare;   //燃烧占比

    //关键地址
    address public immutable pair;  //流动性池对地址
    address public treasuryWallet;  //国库地址
    address public marketingWallet; //营销地址

    //交易限制
    uint256 public maxTransactionAmount;    //单笔最大交易限额
    uint256 public maxWalletSize;   //最大钱包持有量
    uint256 public maxDailyTransactions;    //每日最大交易次数

    //交易计数跟踪
    mapping (address => uint256) public dailyTransactionCount;  //每个地址每日交易的数量
    mapping (address => uint256) public lastTransactionTimestamp;   //每个地址最近的一次交易时间戳

    //钱包地址状态
    mapping (address => bool) public isExcludedFromTax; //被排除在交易税之外的地址
    mapping (address => bool) public isBlackedListed;   //是否是黑名单地址

    // 事件
    event TaxRatesUpdated(uint256 buyTax, uint256 sellTax); // 税率更新事件
    event TaxDistributionUpdated(uint256 liquidityShare, uint256 treasuryShare, uint256 burnShare); //税收分配比例更新事件
    event TransactionLimitsUpdated(uint256 maxTxAmount, uint256 maxWallet, uint256 maxDailyTx); //交易限制更新事件
    event WalletStatusUpdated(address indexed wallet, bool isExcluded, bool isBlacklisted); //钱包地址状态(交易税排除、黑名单)更新事件

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        address _pair,
        address _treasuryWallet,
        address _marketingWallet
    ) ERC20(name, symbol) Ownable(msg.sender) {
        //初始化地址
        pair = _pair;
        treasuryWallet = _treasuryWallet;
        marketingWallet = _marketingWallet;

        //初始化税率
        buyTax = 10;    //买入税10%
        sellTax = 15;   //卖出税15%

        //初始化税收分配
        liquidityShare = 50;    //50%进入流动性
        treasuryShare = 30; //30%进入国库
        burnShare = 20; //20%销毁

        //初始化交易限制
        maxTransactionAmount = totalSupply / 100;   //单笔最大交易限额为总供应量的1%
        maxWalletSize = totalSupply / 50;   //最大钱包持有量为总供应量的2%
        maxDailyTransactions = 10;  //每日最大交易次数为10次

        //铸造初始代币
        _mint(msg.sender, totalSupply);

        //记录事件
        emit TaxRatesUpdated(buyTax, sellTax);
        emit TaxDistributionUpdated(liquidityShare, treasuryShare, burnShare);
        emit TransactionLimitsUpdated(maxTransactionAmount, maxWalletSize, maxDailyTransactions);
    }

    //更新税率-仅所有者调用
    function updateTaxRates(uint256 _buyTax, uint256 _sellTax) external onlyOwner {
        require(_buyTax <= 30 && _sellTax <= 30, "tax rate too higher");
        buyTax = _buyTax;
        sellTax = _sellTax;
        emit TaxRatesUpdated(_buyTax, _sellTax);
    }

    //更新税收分配-仅所有者调用
    function updateTaxShare(uint256 _liquidityShare, uint256 _treasuryShare, uint256 _burnShare) external onlyOwner {
        require(_liquidityShare + _treasuryShare + _burnShare == 100, "Distribution must sum to 100");
        liquidityShare = _liquidityShare;
        treasuryShare = _treasuryShare;
        burnShare = _burnShare;
        emit TaxDistributionUpdated(_liquidityShare, _treasuryShare, _burnShare);
    }
    //更新交易限制-仅所有者调用
    function updateTransactionLimits(uint256 _maxTransactionAmount, uint256 _maxWalletSize, uint256 _maxDailyTransactions) external onlyOwner {
        maxTransactionAmount = _maxTransactionAmount;
        maxWalletSize = _maxWalletSize;
        maxDailyTransactions = _maxDailyTransactions;
        emit TransactionLimitsUpdated(_maxTransactionAmount, _maxWalletSize, _maxDailyTransactions);
    }
    //更新钱包状态(税收排除，黑名单)-仅所有者调用
    function updateWalletStatus(address _wallet, bool _isExcludedTax, bool _blacklist) external onlyOwner {
        require(_wallet != address(0), "address must not be address 0");
        isExcludedFromTax[_wallet] = _isExcludedTax;
        isBlackedListed[_wallet] = _blacklist;
        emit WalletStatusUpdated(_wallet, _isExcludedTax, _blacklist);
    }

    //检查交易是买入还是卖出
    function isBuyTransaction(address sender, address recipient) internal view returns(bool) {
        return sender == pair && recipient != pair;
    }
    function isSellTransaction(address sender, address recipient) internal view returns(bool) {
        return recipient == pair && sender != pair;
    }

    //检查是否为新的一天
    function isNewDay(address _address) internal view returns(bool) {
        return block.timestamp - lastTransactionTimestamp[_address] > 1 days;
    }

    //重置每日交易计数
    function resetDailytTransactionCount(address _address) internal {
        lastTransactionTimestamp[_address] = block.timestamp;
        dailyTransactionCount[_address] = 0;
    }

    //检查交易限制
    function checkTransactionLimits(address sender, address recipient, uint256 amount) internal {
        //检查是否在黑名单
        require(!isBlackedListed[sender] && !isBlackedListed[recipient], "address is blackListed");
        //检查单笔交易限额
        require(amount <= maxTransactionAmount, "amount exceeds max transaction limit");
        //检查钱包持有量限制
        if (recipient != pair && !isExcludedFromTax[recipient]) {
            require(balanceOf(recipient) + amount <= maxWalletSize, "exceeds max wallet size");
        }
        //检查是否是新的一天，并重置
        if (isNewDay(sender)) {
            resetDailytTransactionCount(sender);
        }
        //检查每日交易次数
        require(dailyTransactionCount[sender] <= maxDailyTransactions, "exceed max daily transaction");

        dailyTransactionCount[sender]++;
    }

    //计算并分配税费
    function calculateAndDistributeTaxes(address sender, address recipient, uint256 amount) internal returns(uint256) {
        //排除的地址不收税费
        if (isExcludedFromTax[sender] && isExcludedFromTax[recipient]) {
            return amount;
        }
        //确定税率
        uint256 taxRate;
        if (isBuyTransaction(sender, recipient)) {
            taxRate = buyTax;
        } else if (isSellTransaction(sender, recipient)) {
            taxRate = sellTax;
        } else {
            taxRate = 0;
        }
        if (taxRate == 0) {
            return amount;
        }

        //计算税费
        uint256 taxAmount = (amount * taxRate) / 100;
        uint256 transferAmount = amount - taxAmount;

        //计算各项分配税收
        uint256 liquidityAmount = (taxAmount * liquidityShare) / 100;
        uint256 treasuryAmount = (taxAmount * treasuryShare) / 100;
        uint256 burnAmount = taxAmount - liquidityAmount - treasuryAmount;

        //分配税收
        if (liquidityAmount > 0) {
            _transfer(sender, pair, liquidityAmount);
        }
        if (treasuryAmount > 0 && treasuryWallet != address(0)) {
            _transfer(sender, treasuryWallet, treasuryAmount);
        }
        if (burnAmount > 0) {
            _burn(sender, burnAmount);
        }

        return transferAmount;
    }

    //重写transfer，实现交易限制和税收
    function transfer(address recipient, uint256 amount) public override returns(bool) {
        checkTransactionLimits(_msgSender(), recipient, amount);
        uint256 transferAmount = calculateAndDistributeTaxes(_msgSender(), recipient, amount);
        return super.transfer(recipient, transferAmount);
    }
    //增加流动性
    function addLiquidity(uint256 tokenAmount) external payable nonReentrant {
        require(tokenAmount > 0 && msg.value > 0, "amounts must be greather than 0");
        require(balanceOf(msg.sender) > tokenAmount, "Insufficient token balance");

        _transfer(msg.sender, pair, tokenAmount);
    }

    //紧急提款
    function emergencyWithdrawn() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner()).transfer(balance);
        }
    }

}