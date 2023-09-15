// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {FundMe} from "../../src/FundMe.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMininmumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
        assertEq(fundMe.getOwnerAddress(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert();

        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders()
        public
    /*funders.push проверяем, путем сравнения гетера и сетера*/ {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.expectRevert(); /*должна вернуть первую нижнюю*/
        vm.prank(USER);
        fundMe.withdraw();
        /*юзер попытается вывести баблишко*/
    }

    function testWithDrawWithASingleFunder() public funded {
        uint256 startingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 gasStart = gasleft();

        vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwnerAddress());
        fundMe.withdraw();

        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log(gasUsed);

        uint256 endingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingOwnerBalance + startingFundMeBalance,
            endingOwnerBalance
        ); /*cнимаем все деньги с контракта*/
    }

    function testWithdrawFromMultipleFunders() public funded {
        uint160 numbersOfFunders = 10;
        uint160 startingFundedIndex = 1;

        for (uint160 i = startingFundedIndex; i < numbersOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{
                value: SEND_VALUE
            }(); /*создаем адреса и баланс через хоакс и внутри цикла перебирая отправляя с каждого бало*/
        }

        uint256 startingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwnerAddress());
        fundMe.withdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwnerAddress().balance
        );
    }

    function testWithdrawFromMultipleFundersCheaper() public funded {
        uint160 numbersOfFunders = 10;
        uint160 startingFundedIndex = 1;

        for (uint160 i = startingFundedIndex; i < numbersOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{
                value: SEND_VALUE
            }(); /*создаем адреса и баланс через хоакс и внутри цикла перебирая отправляя с каждого бало*/
        }

        uint256 startingOwnerBalance = fundMe.getOwnerAddress().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        vm.startPrank(fundMe.getOwnerAddress());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwnerAddress().balance
        );
    }
}
