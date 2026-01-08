/// Module: escrow
module escrow::escrow;

use std::ascii::String;
use sui::event;
use sui::balance::Balance;
use sui::coin::Coin;
use sui::clock::Clock;

public enum Occurrence has store, drop, copy {
    Daily,
    Weekly,
    Monthly
}

public struct Data has store, copy, drop {
    share: u64,
    target_chain: String,
    target_address: String,
}


public struct PersonalEscrow <phantom T> has key{
    id: UID,
    balance: Balance<T>,
    buy_amt: u64,
    owner: address,
    occurrence: Occurrence,
    data: vector<Data>,
    next_buy_ts: u64,
}

public struct PersonalEscrowCap has key {
    id: UID,
    `for`: ID,
}

public struct PersonalEscrowApproverCap has key {
    id: UID,
    `for`: ID,
}

public struct EscrowCreatedEvent has store, copy, drop {
    escrow: ID,
    owner: address,
    occurrence: Occurrence,
    data: vector<Data>,
    next_buy_ts: u64,
    admin_cap_id: ID,
    owner_cap_id: ID,
    buy_amt: u64,
    total_amt: u64,
}

public struct UpdateEscrowNextBuy has store, copy, drop {
    escrow: ID,
    owner: address,
    next_buy_ts: u64
}

public struct ApproverFundMove has store, copy, drop {
    escrow: ID,
    amount: u64,
    current_ts: u64,
    next_buy_ts: u64,
}

// === Constants ===
const MS_IN_WEEK: u64 = 604_800_000;    // 7 * 24 * 60 * 60 * 1000
const MS_IN_MONTH: u64 = 2_592_000_000; // 30 * 24 * 60 * 60 * 1000

/// Error codes
const EZeroAmount: u64 = 0;
// const ENotYetTime: u64 = 1;
const EInvalidEscrow: u64 = 2;


public fun create_escrow<T>(
    amt: Coin<T>,
    occurrence: u8,
    buy_amt: u64,
    next_buy: u64,
    data: vector<Data>,
    clock: &Clock,
    ctx: &mut TxContext,
){
    let total_amt = amt.value();
    assert!( total_amt > 0, EZeroAmount);
    let occ = occurrence_from_u8(occurrence);
    let now = clock.timestamp_ms();
    // let next_buy = calculate_next_buy_ts(now, &occ);
    
    let pe = PersonalEscrow {
        id: object::new(ctx),
        buy_amt,
        balance: amt.into_balance(),
        owner: ctx.sender(),
        occurrence: occurrence_from_u8(occurrence),
        data: data,
        next_buy_ts: next_buy,
    };
    let escrow_cap = PersonalEscrowCap { 
        id: object::new(ctx),
        `for`: object::id(&pe)
    };
    let escrow_approver = PersonalEscrowApproverCap { 
        id: object::new(ctx),
        `for`: object::id(&pe)
    };
    transfer::transfer(escrow_approver, @admin);
    
    event::emit(EscrowCreatedEvent {
        escrow: object::id(&pe),
        owner: ctx.sender(),
        occurrence: occurrence_from_u8(occurrence),
        data: data,
        next_buy_ts: next_buy,
        buy_amt,
        owner_cap_id: object::id(&escrow_cap),
        admin_cap_id: object::id(&escrow_cap),
        total_amt
    });
    transfer::share_object(pe);
    transfer::transfer(escrow_cap, ctx.sender())
}

/// Convert u8 to Occurrence enum
fun occurrence_from_u8(value: u8): Occurrence {
    if (value == 0) {
        Occurrence::Daily
    } else if (value == 1) {
        Occurrence::Weekly
    } else {
        Occurrence::Monthly
    }
}

public fun update_escrow<T>(
    escrow_cap: &PersonalEscrowCap,
    balance: Coin<T>,
    occurrence: u8,
    pe: &mut PersonalEscrow<T>
){
    assert!(object::id(pe) == escrow_cap.`for`, EInvalidEscrow);

    pe.balance.join(balance.into_balance());
    pe.occurrence = occurrence_from_u8(occurrence);
}

public fun owner_fetch_fund<T>(
    escrow_cap: &PersonalEscrowCap,
    pe: &mut PersonalEscrow<T>
){
    // TODO
    assert!(object::id(pe) == escrow_cap.`for`, EInvalidEscrow);
}

public fun approve_fetch_fund<T>(
    escrow_cap: &PersonalEscrowApproverCap,
    pe: &mut PersonalEscrow<T>,
    next_buy: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<T> {
    // assert!(clock.timestamp_ms() >= pe.next_buy_ts, ENotYetTime);
    assert!(object::id(pe) == escrow_cap.`for`, EInvalidEscrow);
    let now = clock.timestamp_ms();
    let b = pe.balance.split(pe.buy_amt);
    //let next_buy = calculate_next_buy_ts(now, &pe.occurrence);
    event::emit(ApproverFundMove {
        escrow: object::id(pe),
        amount: b.value(),
        current_ts: now,
        next_buy_ts: next_buy,
    });
    b.into_coin(ctx)
}

public fun update_next_buy_ts<T>(
    escrow_cap: &PersonalEscrowApproverCap,
    pe: &mut PersonalEscrow<T>,
    next_buy: u64,
    clock: &Clock,
){
    let now = clock.timestamp_ms();
    // let next_buy = calculate_next_buy_ts(now, &pe.occurrence);
    assert!(object::id(pe) == escrow_cap.`for`, EInvalidEscrow);
    pe.next_buy_ts = next_buy;
    event::emit(UpdateEscrowNextBuy {
        escrow: object::id(pe),
        owner: pe.owner,
        next_buy_ts: next_buy,
    })
}

// Add this helper function to your escrow module
public fun create_data(
    share: u64, 
    target_chain: String, 
    target_address: String
): Data {
    Data { share, target_chain, target_address }
}

/// Helper to get occurrence as u8 (for indexing/events)
fun occurrence_to_u8(occurrence: &Occurrence): u8 {
    match (occurrence) {
        Occurrence::Daily => 0,
        Occurrence::Weekly => 1,
        Occurrence::Monthly => 2,
    }
}

/// Calculate next buy timestamp based on occurrence
fun calculate_next_buy_ts(
    now: u64, 
    occurrence: &Occurrence
): u64 {
    match (occurrence) {
        Occurrence::Daily => now,                  // Instant
        Occurrence::Weekly => now + MS_IN_WEEK,    // +7 days
        Occurrence::Monthly => now + MS_IN_MONTH,  // +30 days
    }
}
