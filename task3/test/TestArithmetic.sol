// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Arithmetic} from "../src/Arithmetic.sol";

contract TestArithmetic is Test{
    Arithmetic public arithmetic;

    function setUp() public {
        arithmetic = new Arithmetic();
    }
    //功能测试
    function testAdd() public {
        arithmetic.add(2, 3);
        assertEq(arithmetic.result(), 5);
    }

    function testSub() public {
        arithmetic.sub(5, 2);
        assertEq(arithmetic.result(), 3);
    }

    function testSubRevert() public {
        vm.expectRevert("Cannot sub larger number from smaller one");
        arithmetic.sub(2, 5);
    }

    function testMul() public {
        arithmetic.mul(3, 4);
        assertEq(arithmetic.result(), 12);
    }

    function testDiv() public {
        arithmetic.div(10, 2);
        assertEq(arithmetic.result(), 5);
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
