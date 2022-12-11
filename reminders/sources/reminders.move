module Std::reminder_list {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::table::{Self,Table};

//:!:>resource 
    struct ReminderList has key {
        reminders: Table<u64,string::String>,
        reminder_add_events: event::EventHandle<ReminderAddEvent>,
        reminder_delete_events: event::EventHandle<ReminderDeleteEvent>,
    }
//<:!:resource
    struct Reminder has drop,store{
        id: u64,
        title: string::String,
    }
//<:!:resource
    struct ReminderAddEvent has drop, store {
        id: u64,
        title: string::String,
    }
//<:!:resource
    struct ReminderDeleteEvent has drop, store {
        id: u64,
    }

    const ENO_MESSAGE:u64 = 0;

    public fun get_reminder(addr: address, id: u64): string::String acquires ReminderList {
        assert!(exists<ReminderList>(addr), error::not_found(ENO_MESSAGE));
        let reminder_list = borrow_global<ReminderList>(addr);
        *table::borrow(&reminder_list.reminders, id)
    }

    public entry fun delete_reminder(account: signer, id:u64) acquires ReminderList {
        let account_addr = signer::address_of(&account);
        assert!(exists<ReminderList>(account_addr), error::not_found(ENO_MESSAGE));
        let reminder_list =  borrow_global_mut<ReminderList>(account_addr);
        event::emit_event(&mut reminder_list.reminder_delete_events, ReminderDeleteEvent {
                id,
        });
        table::remove<u64,string::String>(&mut reminder_list.reminders,id);
    }

    public entry fun add_reminder(account: signer, id: u64,title: string::String) acquires ReminderList {
        let account_addr = signer::address_of(&account);
        if (!exists<ReminderList>(account_addr)) {
            let reminders = table::new<u64,string::String>();
            table::add(&mut reminders,id,title);
            move_to(&account, ReminderList {
                reminders: reminders,
                reminder_add_events: account::new_event_handle<ReminderAddEvent>(&account),
                reminder_delete_events: account::new_event_handle<ReminderDeleteEvent>(&account),
            });
            let reminder_list = borrow_global_mut<ReminderList>(account_addr);
            event::emit_event(&mut reminder_list.reminder_add_events, ReminderAddEvent {
                id,
                title,
            });
        } else {
            let old_reminder_list = borrow_global_mut<ReminderList>(account_addr);
            assert!(!table::contains(&mut old_reminder_list.reminders,id),0);
            event::emit_event(&mut old_reminder_list.reminder_add_events, ReminderAddEvent {
                id,
                title,
            });
            table::add(&mut old_reminder_list.reminders,id,title);
        }
    }

    #[test(account = @0x1)]
    public entry fun reminder_test(account: signer) acquires ReminderList {
        let addr = signer::address_of(&account);
        aptos_framework::account::create_account_for_test(addr);
        add_reminder(account, 1111 , string::utf8(b"Hello, Blockchain"));
        let reminder = get_reminder(addr,1111);
        assert!(reminder==string::utf8(b"Hello, Blockchain"),1);
    }
}
