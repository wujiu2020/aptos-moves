#[test_only]
module 0x43501e1d605075a7cd7047f735224beafb6f67c30b391315ff376374f39c1109::message_tests {
    use std::signer;
    use std::unit_test;
    use std::vector;
    use std::string;

    use 0x43501e1d605075a7cd7047f735224beafb6f67c30b391315ff376374f39c1109::message;

    fun get_account(): signer {
        vector::pop_back(&mut unit_test::create_signers_for_testing(1))
    }

    #[test]
    public entry fun sender_can_set_message() {
        let account = get_account();
        let addr = signer::address_of(&account);
        aptos_framework::account::create_account_for_test(addr);
        message::set_message(account,  string::utf8(b"Hello, Blockchain"));

        assert!(
          message::get_message(addr) == string::utf8(b"Hello, Blockchain"),
          0
        );
    }
}
