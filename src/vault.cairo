// Cross contract interactions. This is a basic cross contract interaction.
// The Vault contract accessing the erc20 contract.
// The Vault contract makes use of the functions of the erc20 contract

use core::starknet::ContractAddress;
#[starknet::interface]
pub trait IVault<TContractState> {
    fn deposit(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn withdraw(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn balance(self: @TContractState, token_address: ContractAddress, amount: u256) -> u256;
}

#[starknet::contract]
pub mod Vault {
    use super::IVault;

    use crossinteract::erc20::{
        IERC20Dispatcher, IERC20DispatcherTrait
    }; // cross contract interaction
    use core::starknet::{
        ContractAddress, get_caller_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess}
    };

    #[storage]
    struct Storage {
        balance: Map<
            (ContractAddress, ContractAddress), u256
        >, // map user address, token address to an ammount
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    #[abi(embed_v0)] // makes this accessible from outside the contract
    impl VaultImpl of IVault<ContractState> {
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let caller = get_caller_address(); // owner of the contract
            // connect to erc20
            let token_dispatcher = IERC20Dispatcher {
                contract_address: token_address
            }; // accessing the ERC20 interfaces

            // Check if amount is greater than zero
            assert(amount > 0, 'amount should be more than zero');

            token_dispatcher.transfer(caller, amount);

            let current_balance = self.balance.read((caller, token_address));
            self.balance.write((caller, token_address), current_balance + amount);
        }

        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            let caller = get_caller_address(); // owner of the contract
            // connect to erc20
            let erc20_dispatcher = IERC20Dispatcher {
                contract_address: token_address
            }; // accessing the ERC20 interfaces

            erc20_dispatcher.transfer(caller, amount);

            let current_balance = self.balance.read((caller, token_address));
            self.balance.write((caller, token_address), current_balance - amount);
        }

        fn balance(self: @ContractState, token_address: ContractAddress, amount: u256) -> u256 {
            let caller = get_caller_address();
            self.balance.read((caller, token_address))
        }
    }
}
