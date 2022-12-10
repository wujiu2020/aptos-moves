module Std::funding {
    use std::signer;
    use std::string::{Self,String};
    use std::vector;
    use std::debug;
    use std::timestamp;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::table::{Self,Table};
    use aptos_framework::coin::{Self,Coin};

//:!:>resource
    struct FundingList<phantom CoinType> has key{
        fundings: Table<u64, Funding<CoinType>>,
        funding_create_event: event::EventHandle<FundingCreateEvent>,
        funding_support_event: event::EventHandle<FundingSupportEvent>,
    }

    const FUNDING_INIT:u8 = 0;
    const FUNDING_SUCCESS:u8 = 1;
    const FUNDING_FAIL:u8 = 2 ;
    //todo add error code

//:!:>resource
    struct Funding<phantom CoinType> has store {
        project_name: string::String,
        target_balance: u64,
        support_balance: u64,
        unlock_time_secs: u64,
        current_balance: u64,
        status: u8,
        supports: vector<address>,
        supprot_coins: vector<Coin<CoinType>>,
    }

    struct FundingCreateEvent has drop, store {
        funding_id: u64,
        project_name: string::String,
        target_balance: u64,
        support_balance: u64,
        unlock_time_secs: u64,   
    }

    struct FundingSupportEvent has drop, store {
        funding_id: u64,
        support_amount: u64,
        support_address: address,   
    }

    public entry fun create_fund<CoinType>(account: signer, project_name: String, target_balance: u64, 
    support_balance: u64, unlock_time_secs: u64,funding_id: u64) acquires FundingList {
        // get creator address
        let account_addr = signer::address_of(&account);
        // new funding
        let funding = Funding<CoinType>{
            project_name,
            target_balance,
            support_balance,
            unlock_time_secs,
            status: FUNDING_INIT,
            current_balance : 0,
            supports: vector::empty<address>(),
            supprot_coins: vector::empty<Coin<CoinType>>(),
        };
        // check if the resource has been exist
        if (!exists<FundingList<CoinType>>(account_addr)) {
            let fundings = table::new<u64,Funding<CoinType>>();
            table::add(&mut fundings,funding_id,funding);
            // move resource to creator
            move_to(&account, FundingList<CoinType> {
                fundings: fundings,
                funding_create_event: account::new_event_handle<FundingCreateEvent>(&account),
                funding_support_event: account::new_event_handle<FundingSupportEvent>(&account),
            });
            let old_fundinglist = borrow_global_mut<FundingList<CoinType>>(account_addr);
            event::emit_event(&mut old_fundinglist.funding_create_event, FundingCreateEvent {
                funding_id,
                project_name,
                target_balance,
                support_balance,
                unlock_time_secs,
            });
        }else{
            let old_fundinglist = borrow_global_mut<FundingList<CoinType>>(account_addr);
            assert!(table::contains(&mut old_fundinglist.fundings, funding_id), 0);
            // create funding
            table::add(&mut old_fundinglist.fundings,funding_id,funding);
            event::emit_event(&mut old_fundinglist.funding_create_event, FundingCreateEvent {
                funding_id,
                project_name,
                target_balance,
                support_balance,
                unlock_time_secs,
            });
        };
    }

     public entry fun get_funding<CoinType>(fund_address: address,funding_id: u64): (string::String,u64,u64) acquires FundingList {
        let fundings = borrow_global<FundingList<CoinType>>(fund_address);
        let funding = table::borrow<u64,Funding<CoinType>>(&fundings.fundings,funding_id);
        return (funding.project_name, funding.target_balance, funding.current_balance)
     }

    public entry fun support<CoinType>(supporter: signer, target_address: address,funding_id: u64,amount: u64) acquires FundingList {
        // check target address if has the resource
        assert!(!exists<FundingList<CoinType>>(target_address),0);
        // get the resource of target address
        let old_fundinglist = borrow_global_mut<FundingList<CoinType>>(target_address);
        // check if the resource contains the funding
        assert!(!table::contains(&mut old_fundinglist.fundings, funding_id), 0);
        let funding = table::borrow_mut(&mut old_fundinglist.fundings, funding_id);
        // check if the funding has been closed
        assert!(timestamp::now_seconds()<=funding.unlock_time_secs, 0);
        assert!(funding.support_balance == amount, 0);
        let coins = coin::withdraw<CoinType>(&supporter, amount);
        let support_address = signer::address_of(&supporter);
        // check if the funding contains the supporter
        assert!(vector::contains(&mut funding.supports, &support_address),0);
        // add support
        vector::push_back(&mut funding.supports,support_address);
        vector::push_back(&mut funding.supprot_coins,coins);
        funding.current_balance = funding.current_balance + amount;
        // send event
        event::emit_event(&mut old_fundinglist.funding_support_event, FundingSupportEvent {
            funding_id:funding_id,
            support_amount:amount,
            support_address:support_address,
        });
    }

    // every one can finish funding if the funding has not been closed and the unlock_time_secs litter than current timestamp second
    public entry fun finish_fund<CoinType>(funding_address: address ,funding_id: u64) acquires FundingList {
        assert!(!exists<FundingList<CoinType>>(funding_address),0);
        // get the resource of target address
        let old_fundinglist = borrow_global_mut<FundingList<CoinType>>(funding_address);
        // check if the resource contains the funding
        assert!(!table::contains(&mut old_fundinglist.fundings, funding_id), 0);
        let funding = table::borrow_mut(&mut old_fundinglist.fundings, funding_id);
        assert!(timestamp::now_seconds()>funding.unlock_time_secs, 0);
        assert!(funding.status==0, 0);
        let len = vector::length<address>(&funding.supports);
        // funding success deposit coins to funder
        if (funding.current_balance>=funding.target_balance){
            let i = 0;
            while (i < len){
                let support_coins = vector::pop_back<Coin<CoinType>>(&mut funding.supprot_coins);
                coin::deposit(funding_address, support_coins);
                i = i + 1;
            };
            funding.status = FUNDING_SUCCESS
        // funding fail deposit coins to supports
        }else{
            let i = 0;
            while (i < len){
                let supportor_address = vector::borrow<address>(&funding.supports,len-i-1);
                let support_coins = vector::pop_back<Coin<CoinType>>(&mut funding.supprot_coins);
                coin::deposit(*supportor_address, support_coins);
                i = i + 1;
            };
            funding.status = FUNDING_FAIL
        }
    }

    #[test_only]
    use aptos_framework::aptos_coin::AptosCoin;

    #[test(account = @0x1)]
    public entry fun test_vector(account: signer) acquires FundingList {
        let funding_address = signer::address_of(&account);
        aptos_framework::account::create_account_for_test(funding_address);
        create_fund<AptosCoin>(account, string::utf8(b"Hello, Blockchain"), 100, 1, 1, 111111);
        let (funding,target_balance,current_balance) = get_funding<AptosCoin>(funding_address,111111);
        debug::print(&funding);
        debug::print(&target_balance);
        debug::print(&current_balance);
    }
}
