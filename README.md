# SimpleBlockchain

A local blockchain app/demo written in Elixir

## Compilation
`mix deps.get` <br>
`mix compile`

## Running
Make sure that the `.simple_blockchain` folder contains a snapshot of the blockchain and a wallet file. I provided such files in this repository.

In the project directory run `iex -S mix` then in the shell start the app: <br>
`SimpleBlockchain.start_link()`

Currently the only way to interface with the blockchain is via the iex shell. Here is an overview on how to communicate with the blockchain via the iex shell after running the commands shown above.

You can list available accounts using `Wallet.list_accounts()` --- this command will list human friendly id's and their corresponding base64 encoded public keys.

To list the available funds for a given `account_id` run `Wallet.get_funds_for(account_id)`.

To open a new account use: `Wallet.new_wallet()`.

To start mining blocks and to receive the block reward + transaction fees to the `miner_id` account use: `Wallet.start_mining_for(miner_id)`.

To transfer `amount` tokens, with `transaction_fee` as the transaction fee between account id `source_id` to account id `dest_id` use: `Wallet.transfer_between_my_accounts(source_id, dest_id, amount, transaction_fee)`
If the transaction fee is not specified it defaults to 100 tokens.

To transfer `amount` tokens, with `transaction_fee` as the transaction fee from the account with id `source_id` to public key `key` use `Wallet.transfer_funds(source_id, key, amount, transaction_fee)`

## Documentation
Documentation is available and can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc).
