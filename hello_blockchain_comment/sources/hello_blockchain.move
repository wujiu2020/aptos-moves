module hello_blockchain::message {
    use std::error;
    use std::signer;
    use std::string;
    use aptos_framework::account;
    use aptos_framework::event;
/*
这四种 abilities 限制符分别是: Copy, Drop, Store 和 Key.
- Copy - 被修饰的值可以被复制。
- Drop - 被修饰的值在作用域结束时可以被丢弃。
- Key - 被修饰的值可以作为键值对全局状态进行访问。
- Store - 被修饰的值可以被存储到全局状态。
*/

//:!:>resource 必须具备 key
    struct MessageHolder has key {
        message: string::String,
        message_change_events: event::EventHandle<MessageChangeEvent>,
    }
//<:!:resource

    struct MessageChangeEvent has drop, store {
        from_message: string::String,
        to_message: string::String,
    }

    /// There is no message present
    const ENO_MESSAGE: u64 = 0;

    // 指定方法使用到的resource
    public fun get_message(addr: address): string::String acquires MessageHolder {
        // 断言 address 是否有resource exists<MessageHolder>(addr)
        assert!(exists<MessageHolder>(addr), error::not_found(ENO_MESSAGE));
        // borrow_global 不可变引用 获取指定地址的resource
        *&borrow_global<MessageHolder>(addr).message
    }

    // signer 是原生类型，使用前必须先创建，不能在代码中创建可以作为脚本传值
    public entry fun set_message(account: signer, message: string::String) acquires MessageHolder {
        // 获取signer address
        let account_addr = signer::address_of(&account);
        if (!exists<MessageHolder>(account_addr)) {
            // 移动resource 到 指定的signer
            move_to(&account, MessageHolder {
                message,
                message_change_events: account::new_event_handle<MessageChangeEvent>(&account),
            })
        } else {
            // borrow_global_mut resource 可变借用
            // borrow_global resource 不可变借用
            let old_message_holder = borrow_global_mut<MessageHolder>(account_addr);
            let from_message = *&old_message_holder.message;
            // 抛出事件
            event::emit_event(&mut old_message_holder.message_change_events, MessageChangeEvent {
                from_message,
                to_message: copy message,
            });
            old_message_holder.message = message;
        }
    }

    #[test(account = @0x1)]
    public entry fun sender_can_set_message(account: signer) acquires MessageHolder {
        let addr = signer::address_of(&account);
        aptos_framework::account::create_account_for_test(addr);
        set_message(account,  string::utf8(b"Hello, Blockchain"));

        assert!(
          get_message(addr) == string::utf8(b"Hello, Blockchain"),
          ENO_MESSAGE
        );
    }
}
