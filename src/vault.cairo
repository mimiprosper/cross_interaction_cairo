// Cross contract interactions. This is a basic cross contract interaction.
// The Vault contract accesses the erc20 contract.
// The Vault contract makes use of the functions of the erc20 contract

// import ContractAddress module
use core::starknet::ContractAddress;

// interface of Vault Contracts
#[starknet::interface]
pub trait IVault<TContractState> {
    // for fund deposit
    fn deposit(ref self: TContractState, token_address: ContractAddress, amount: u256);
    // for fund withdrawal
    fn withdraw(ref self: TContractState, token_address: ContractAddress, amount: u256);
    // check account balance
    fn balance(self: @TContractState, token_address: ContractAddress) -> u256;
}

// Vault Contract
#[starknet::contract]
pub mod Vault {
    // import Vault Interface
    use super::IVault;
    // import package (crossinteract), ERC20 module, ERC20 Dispatcher & ERC20 DispatcherTrait
    // for CROSS CONTRACT INTERACTION
    use crossinteract::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    // import ContractAddress module, get caller address module &
    // Mapping module for reading and writing to storage
    use core::starknet::{
        ContractAddress, get_caller_address,
        storage::{Map, StorageMapReadAccess, StorageMapWriteAccess},
    };

    // map user address, token address to an ammount
    #[storage]
    struct Storage {
        // map <(user address, token address), amount>
        balance: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {}

    // make it accessible by other contracts
    #[abi(embed_v0)]
    // implement the interface
    impl VaultImpl of IVault<ContractState> {
        // this function deposites funds into the vault
        fn deposit(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            //get caller of the contract
            let caller = get_caller_address();
            // Check if amount is greater than zero
            assert(amount > 0, 'amount should be more than zero');
            // connect to erc20 interface via the dispatcher
            let token_dispatcher = IERC20Dispatcher {
                contract_address: token_address // accessing the ERC20 interfaces
            };
            // transfer funds from the caller & amount to be transferred
            token_dispatcher.transfer(caller, amount);
            // get current balance in the vault
            let current_balance = self.balance.read((caller, token_address));
            // write the balance to the storage (state)
            // ie mapping the caller address and token address to an amount
            self.balance.write((caller, token_address), current_balance + amount);
        }

        // this function withdraws funds from the vault
        fn withdraw(ref self: ContractState, token_address: ContractAddress, amount: u256) {
            // get the caller of the contract
            let caller = get_caller_address();
            // check the current balance in the vault
            let current_balance = self.balance.read((caller, token_address));
            // check current balance is greater or equals to amount to be withdrawn
            assert(current_balance >= amount, 'Insufficient Funds');
            // connect to erc20 
            let erc20_dispatcher = IERC20Dispatcher {
                contract_address: token_address // accessing the ERC20 interfaces
            };
            // caller withdraws an amount of token from the vault
            erc20_dispatcher.transfer(caller, amount);
            // write the balance to the storage (state)
            // ie mapping the caller address and token address to an amount
            self.balance.write((caller, token_address), current_balance - amount);
        }

        // this function get the balance of the vault
        fn balance(self: @ContractState, token_address: ContractAddress) -> u256 {
            // gets the caller contract address
            let caller = get_caller_address();
            // gets the current balance of the vault
            self.balance.read((caller, token_address))
        }
    }
}
