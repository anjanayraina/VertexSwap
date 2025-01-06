// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Core/MultiTokenVault.sol";
import "forge-std/StdAssertions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiTokenVaultTest is Test {
    MultiTokenVault public vault;
    IERC20 public usdc; // USDC contract on mainnet
    IERC20 public weth; // WETH contract on mainnet

    address public constant USDC_ADDRESS = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address public constant WETH_ADDRESS = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address public constant USDC_ORACLE = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
    address public constant WETH_ORACLE = 0xF9680D99D6C9589e2a93a78A04A279e509205945;

    address public alice;

    function setUp() public {
        // Fork the mainnet
        vm.createSelectFork(vm.envString("FORK_URL"));

        // Initialize vault
        vault = new MultiTokenVault("MultiToken Vault", "MTV", address(this));
        vault.addToken(USDC_ADDRESS, USDC_ORACLE);
        vault.addToken(WETH_ADDRESS, WETH_ORACLE);

        usdc = IERC20(USDC_ADDRESS);
        weth = IERC20(WETH_ADDRESS);

        // Fund Alice's account for testing
        alice = address(0x1);
        deal(USDC_ADDRESS, alice, 1_000 * 10**6); // 1M USDC
        deal(WETH_ADDRESS, alice, 1 * 10**18); // 100 WETH
    }

    function testDeposit() public {
        vm.startPrank(alice);

        // Approve vault for USDC and deposit
        usdc.approve(address(vault), 1_000 * 10**6);
        uint256 shares = vault.deposit(USDC_ADDRESS, 1_000 * 10**6, alice);

        // Verify shares were minted
        assertEq(vault.balanceOf(alice), shares, "Shares should match deposit value");

        // Verify total assets increased
        uint256 totalAssets = vault.totalAssets();
        assertGt(totalAssets, 0, "Total assets should increase");

        vm.stopPrank();
    }

    function testWithdrawProportional() public {
        vm.startPrank(alice);

        // Deposit USDC and WETH
        usdc.approve(address(vault), 1_000 * 10**6);
        vault.deposit(USDC_ADDRESS, 1_000 * 10**6, alice);

        weth.approve(address(vault), 1 * 10**18);
        vault.deposit(WETH_ADDRESS, 1 * 10**18, alice);

        // Withdraw all shares
        uint256 shares = vault.balanceOf(alice);
        vault.withdraw(shares, alice);

        // Verify proportional withdrawal
        uint256 usdcBalanceAfter = usdc.balanceOf(alice);
        uint256 wethBalanceAfter = weth.balanceOf(alice);

        assertApproxEqRel(usdcBalanceAfter, 1_000 * 10**6, 1e16, "USDC balance should match proportional withdrawal");
        assertApproxEqRel(wethBalanceAfter, 1 * 10**18, 1e16, "WETH balance should match proportional withdrawal");

        vm.stopPrank();
    }

    function testTotalAssets() public {
        vm.startPrank(alice);

        // Deposit USDC and WETH
        usdc.approve(address(vault), 1_000 * 10**6);
        vault.deposit(USDC_ADDRESS, 1_000 * 10**6, alice);

        weth.approve(address(vault), 1 * 10**18);
        vault.deposit(WETH_ADDRESS, 1 * 10**18, alice);

        // Check total assets in USD
        uint256 totalAssets = vault.totalAssets();
        assertGt(totalAssets, 0, "Total assets should increase with deposits");

        vm.stopPrank();
    }
}
