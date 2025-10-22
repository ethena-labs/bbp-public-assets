// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../contracts/USDe.sol";
import "../../../contracts/StakedUSDeV2.sol";

/**
 * @title Proof of Concept - Cooldown Reset Vulnerability
 * @notice This test demonstrates that calling cooldownAssets() multiple times
 * resets the cooldown period for ALL cooling-down assets, not just the new ones.
 */
contract CooldownResetVulnerabilityPOC is Test {
    USDe public usdeToken;
    StakedUSDeV2 public stakedUSDe;
    address public owner;
    address public rewarder;
    address public alice;

    function setUp() public {
        alice = vm.addr(0xA11CE);
        owner = vm.addr(0x1);
        rewarder = vm.addr(0x123);

        vm.label(alice, "alice");
        vm.label(owner, "owner");
        vm.label(rewarder, "rewarder");

        vm.prank(owner);
        usdeToken = new USDe(owner);
        
        vm.prank(owner);
        stakedUSDe = new StakedUSDeV2(IERC20(address(usdeToken)), rewarder, owner);
        
        vm.prank(owner);
        usdeToken.setMinter(address(this));
    }

    /**
     * @notice POC: Demonstrates that multiple cooldown calls reset the timer for ALL assets
     */
    function test_POC_CooldownResetVulnerability() public {
        // Setup: Alice stakes 2000 USDe
        uint256 totalStake = 2000 ether;
        usdeToken.mint(alice, totalStake);
        
        vm.startPrank(alice);
        usdeToken.approve(address(stakedUSDe), totalStake);
        stakedUSDe.deposit(totalStake, alice);
        
        console.log("\n=== PROOF OF CONCEPT: Cooldown Reset Vulnerability ===\n");
        console.log("Alice staked:", totalStake / 1 ether, "USDe");
        console.log("Current block.timestamp:", block.timestamp);
        
        // DAY 0: Alice initiates cooldown for 1000 USDe
        uint256 firstCooldownAmount = 1000 ether;
        stakedUSDe.cooldownAssets(firstCooldownAmount);
        
        (uint104 cooldownEnd1, uint256 underlyingAmount1) = stakedUSDe.cooldowns(alice);
        
        console.log("\n--- Day 0: First Cooldown ---");
        console.log("Cooldown amount:", firstCooldownAmount / 1 ether, "USDe");
        console.log("Cooldown end timestamp:", cooldownEnd1);
        console.log("Expected unlock:", block.timestamp + 90 days);
        console.log("Total cooling down:", underlyingAmount1 / 1 ether, "USDe");
        
        // FAST FORWARD: 85 days later (5 days before cooldown completes)
        vm.warp(block.timestamp + 85 days);
        console.log("\n--- Day 85: 5 days before first cooldown completes ---");
        console.log("Current timestamp:", block.timestamp);
        console.log("Days until unlock:", (cooldownEnd1 - block.timestamp) / 1 days);
        
        // Verify that Alice COULD withdraw if she waited 5 more days
        console.log("\n[EXPECTED] If Alice waits 5 more days, she can withdraw 1000 USDe");
        
        // DAY 85: Alice initiates SECOND cooldown for 500 USDe
        uint256 secondCooldownAmount = 500 ether;
        stakedUSDe.cooldownAssets(secondCooldownAmount);
        
        (uint104 cooldownEnd2, uint256 underlyingAmount2) = stakedUSDe.cooldowns(alice);
        
        console.log("\n--- Day 85: Second Cooldown Initiated ---");
        console.log("Additional cooldown:", secondCooldownAmount / 1 ether, "USDe");
        console.log("NEW cooldown end timestamp:", cooldownEnd2);
        console.log("Expected NEW unlock:", block.timestamp + 90 days);
        console.log("Total cooling down:", underlyingAmount2 / 1 ether, "USDe");
        
        // THE VULNERABILITY: The cooldown end was RESET!
        console.log("\n=== VULNERABILITY DEMONSTRATED ===");
        console.log("Original cooldown end:", cooldownEnd1);
        console.log("New cooldown end:", cooldownEnd2);
        console.log("Cooldown was extended by:", (cooldownEnd2 - cooldownEnd1) / 1 days, "days");
        
        assertTrue(cooldownEnd2 > cooldownEnd1, "Cooldown end should be extended");
        assertEq(underlyingAmount2, firstCooldownAmount + secondCooldownAmount, "Total should accumulate");
        
        // DAY 90: Alice tries to withdraw the original 1000 USDe that should be ready
        vm.warp(block.timestamp + 5 days); // Now at day 90 total
        console.log("\n--- Day 90: Original cooldown period complete ---");
        console.log("Current timestamp:", block.timestamp);
        console.log("Original cooldown end:", cooldownEnd1);
        console.log("New cooldown end:", cooldownEnd2);
        console.log("Can Alice withdraw? NO - cooldown was reset!");
        
        // This SHOULD work if cooldowns were handled separately, but it WILL REVERT
        vm.expectRevert(); // This will revert with InvalidCooldown because cooldownEnd2 > block.timestamp
        stakedUSDe.unstake(alice);
        
        console.log("\n[VULNERABILITY CONFIRMED] Alice cannot withdraw even though 90 days passed since first cooldown");
        console.log("She must wait until day", (cooldownEnd2 - (block.timestamp - 90 days)) / 1 days);
        console.log("Total wait time from original cooldown:", (cooldownEnd2 - cooldownEnd1 + 90 days) / 1 days, "days");
        
        // DAY 175: Alice can finally withdraw (85 days after second cooldown)
        vm.warp(cooldownEnd2 + 1);
        console.log("\n--- Day 175: Finally able to withdraw ---");
        console.log("Total days waited:", (block.timestamp - (cooldownEnd1 - 90 days)) / 1 days);
        
        stakedUSDe.unstake(alice);
        
        assertEq(usdeToken.balanceOf(alice), firstCooldownAmount + secondCooldownAmount, "Alice should receive all USDe");
        
        console.log("\n=== IMPACT ===");
        console.log("Expected wait time: 90 days");
        console.log("Actual wait time: 175 days");
        console.log("Extra wait imposed: 85 days");
        console.log("This can cause significant losses during volatile markets!");
        
        vm.stopPrank();
    }

    /**
     * @notice POC: Accidental self-DOS scenario
     */
    function test_POC_AccidentalSelfDOS() public {
        // Setup
        usdeToken.mint(alice, 2000 ether);
        
        vm.startPrank(alice);
        usdeToken.approve(address(stakedUSDe), 2000 ether);
        stakedUSDe.deposit(2000 ether, alice);
        
        console.log("\n=== SCENARIO: Accidental Self-DOS ===\n");
        
        // User initiates cooldown for 1000 USDe
        stakedUSDe.cooldownAssets(1000 ether);
        (uint104 cooldownEnd1,) = stakedUSDe.cooldowns(alice);
        
        console.log("User cooldowns 1000 USDe at day 0");
        console.log("Expected unlock: day 90");
        
        // 89 days later, user wants to cooldown 10 more USDe
        // Perhaps they need a small amount of liquidity
        vm.warp(block.timestamp + 89 days);
        
        console.log("\nDay 89: User wants to cooldown 10 more USDe (emergency)");
        console.log("Original 1000 USDe unlocks in: 1 day");
        
        // User calls cooldownAssets for small amount
        stakedUSDe.cooldownAssets(10 ether);
        (uint104 cooldownEnd2, uint256 totalCoolingDown) = stakedUSDe.cooldowns(alice);
        
        console.log("\n[UNEXPECTED BEHAVIOR]");
        console.log("User now has", totalCoolingDown / 1 ether, "USDe cooling down");
        console.log("But ALL of it unlocks on day:", (cooldownEnd2 - (cooldownEnd1 - 90 days)) / 1 days);
        console.log("Original 1000 USDe that was 1 day away is now 90 days away!");
        
        // Verify original funds are locked
        vm.warp(cooldownEnd1 + 1); // Day 90
        vm.expectRevert();
        stakedUSDe.unstake(alice);
        
        console.log("\nDay 90: Original cooldown complete, but withdrawal FAILS");
        console.log("User must wait until day 179 to access ANY funds");
        
        vm.stopPrank();
    }
}
