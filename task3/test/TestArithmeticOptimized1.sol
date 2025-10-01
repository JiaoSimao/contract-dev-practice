// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "../lib/forge-std/src/Test.sol";
import {ArithmeticOptimized1} from "../src/ArithmeticOptimized1.sol";

contract TestArithmetic is Test{
    ArithmeticOptimized1 public arithmetic;

    function setUp() public {
        arithmetic = new ArithmeticOptimized1();
    }
    //功能测试
    function testAdd() public {
        uint256 result = arithmetic.add(2, 3);
        assertEq(result, 5);
    }

    function testSub() public {
        uint256 result = arithmetic.sub(5, 2);
        assertEq(result, 3);
    }

    function testSubRevert() public {
        vm.expectRevert("Cannot sub larger number from smaller one");
        arithmetic.sub(2, 5);
    }

    function testMul() public {
        uint256 result = arithmetic.mul(3, 4);
        assertEq(result, 12);
    }

    function testDiv() public {
        uint256 result = arithmetic.div(10, 2);
        assertEq(result, 5);
    }

    function testDivRevert() public {
        vm.expectRevert("cannot devide by zero");
        arithmetic.div(10, 0);
    }

    //gas消耗测试
    function testGasAdd() public {
        arithmetic.add(1, 1);
    }

    function testGasSub() public {
        arithmetic.sub(2, 1);
    }

    function testGasMul() public {
        arithmetic.mul(1, 1);
    }

    function testGasDiv() public {
        arithmetic.div(10, 2);
    }
}
