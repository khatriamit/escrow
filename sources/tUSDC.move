/// Module: escrow
module escrow::tUSDC;

/// Test USDC (tUSDC) - A test stablecoin for development purposes
use sui::coin::{Self, Coin, TreasuryCap};
use sui::url;

/// One-Time Witness for the coin
public struct TUSDC has drop {}

/// Error codes
const EZeroAmount: u64 = 0;

/// Initialize the tUSDC coin
fun init(witness: TUSDC, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency<TUSDC>(
        witness,
        6, // decimals (same as real USDC)
        b"tUSDC",
        b"Test USDC",
        b"Test stablecoin for development - pegged to nothing, worth nothing",
        option::some(url::new_unsafe_from_bytes(
            b"https://cryptologos.cc/logos/usd-coin-usdc-logo.png"
        )),
        ctx
    );

    // Transfer treasury cap to deployer for minting control
    transfer::public_transfer(treasury_cap, ctx.sender());
    
    // Freeze metadata so it can't be modified
    transfer::public_freeze_object(metadata);
}

/// Mint new tUSDC tokens (only treasury cap holder)
public fun mint(
    treasury_cap: &mut TreasuryCap<TUSDC>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext
) {
    assert!(amount > 0, EZeroAmount);
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient);
}

/// Mint and return the coin (for composability)
public fun mint_coin(
    treasury_cap: &mut TreasuryCap<TUSDC>,
    amount: u64,
    ctx: &mut TxContext
): Coin<TUSDC> {
    assert!(amount > 0, EZeroAmount);
    coin::mint(treasury_cap, amount, ctx)
}

/// Burn tUSDC tokens
public fun burn(
    treasury_cap: &mut TreasuryCap<TUSDC>,
    coin: Coin<TUSDC>
) {
    coin::burn(treasury_cap, coin);
}

/// Get total supply
public fun total_supply(treasury_cap: &TreasuryCap<TUSDC>): u64 {
    coin::total_supply(treasury_cap)
}

// === Test-only functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(TUSDC {}, ctx);
}
