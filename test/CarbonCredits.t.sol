// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CarbonCredits} from "../src/CarbonCredits.sol";

contract CarbonCreditsTest is Test {
    CarbonCredits public carbonCredits;
    address public owner;

    function setUp() public {
        owner = makeAddr("owner");
        vm.startPrank(owner);
        carbonCredits = new CarbonCredits();
        vm.stopPrank();
    }

    function testCreditTypeGetsCreated() public {
        uint256 vintage = 2023;
        string memory projectType = "Solar";
        string memory region = "North America";
        string memory standard = "Gold Standard";

        vm.prank(owner);
        uint256 creditId = carbonCredits.createCreditType(vintage, projectType, region, standard);

        CarbonCredits.CreditType memory creditType = carbonCredits.getCreditTypes(creditId);
        assertEq(creditType.vintage, vintage);
        assertEq(creditType.projectType, projectType);
        assertEq(creditType.region, region);
        assertEq(creditType.standard, standard);
        assertTrue(creditType.isActive);
        assertEq(creditId, 1); // First credit type should have ID 1
    }
}
