// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract Arithmetic {
    uint256 public result;

    //加法
    function add(uint256 a, uint256 b) external {
        result = a + b;
    }
    //减法
    function sub(uint256 a, uint256 b) external {
        require(b <= a, "Cannot sub larger number from smaller one");
        result = a - b;
    }
    //乘法
    function mul(uint256 a, uint256 b) external {
        result = a * b;
    }
    //除法
    function div(uint256 a, uint256 b) external {
        require(b > 0, "cannot devide by zero");
        result = a / b;
    }
}
