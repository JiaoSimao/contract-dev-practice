// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract ArithmeticOptimized1 {
    //加法
    function add(uint256 a, uint256 b) external returns(uint256){
        return a + b;
    }
    //减法
    function sub(uint256 a, uint256 b) external returns(uint256){
        require(b <= a, "Cannot sub larger number from smaller one");
        return a - b;
    }
    //乘法
    function mul(uint256 a, uint256 b) external returns(uint256){
        return a * b;
    }
    //除法
    function div(uint256 a, uint256 b) external returns(uint256){
        require(b > 0, "cannot devide by zero");
        return a / b;
    }
}
