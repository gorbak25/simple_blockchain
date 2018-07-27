defmodule WalletAccount do
  @moduledoc """
  Documentation for WalletAccount.
  This structure represents a wallet entry.
  """

  defstruct [:pub_key, :priv_key]

  @doc """
  Transfers amount of funds from account to dest leaving fee to the miner as the transaction fee.
  Returns {:ok, :registered} if the new transaction was succesfully registered
  returns {:error, reason} otherwise
  """
  def transfer(account, dest, amount, fee) do
    # TODO: prompt user for corfirmation

    %WalletAccount{pub_key: pub, priv_key: priv} = account

    <<nonce::64>> = :crypto.strong_rand_bytes(8)

    body = %TransactionBody{
      from: pub,
      to: dest,
      amount: amount,
      nonce: nonce,
      transaction_fee: fee
    }

    data = TransactionBody.serialize(body)

    signature = :crypto.sign(:ecdsa, :sha256, data, [priv, :secp256k1])

    case TransactionPool.register_new_transaction(%Transaction{
           body: body,
           signature: signature
         }) do
      {:error, :invalid_nonce} -> transfer(account, dest, amount, fee)
      a -> a
    end
  end

  @doc """
  Converts the account to the format needed by the Miner module. 
  """
  def get_details_for_receiving_mining_rewards(%WalletAccount{pub_key: pub, priv_key: priv}) do
    {
      pub,
      :crypto.sign(:ecdsa, :sha256, pub, [priv, :secp256k1])
    }
  end
end

defmodule Wallet do
  @moduledoc """
  Documentation for Wallet.
  This module implements the wallet. The wallet stores the accounts in a local file. This module allows us interface with the blockchain.
  """

  @doc """
  Starts the wallet.
  On startup any local wallets are loaded. The wallet is started by the SimpleBlockchain module.
  """
  def start_link() do
    case Agent.start_link(fn -> %{} end) do
      {:ok, pid} ->
        Process.register(pid, :wallet)
        load_local_wallet()

      {:error, _} ->
        raise "Could not start wallet"
    end
  end

  @doc """
  Loads the accounts from the local wallet file. 
  """
  def load_local_wallet(first \\ false) do
    file = SimpleBlockchain.get_local_wallet_file()

    if File.regular?(file) do
      load_from_disk()
    else
      unless first, do: IO.puts("No wallet found.")

      case IO.gets("Do you want to create a new wallet? (yes/no): ") |> String.trim() do
        "yes" -> new_wallet()
        "no" -> :ok
        _ -> load_local_wallet(true)
      end
    end
  end

  @doc """
  Opens a new account and stores the data in the local wallet file.
  """
  def new_wallet() do
    # 16 bytes --> 128 bits
    entropy_byte_size = 16
    key = :crypto.strong_rand_bytes(entropy_byte_size)
    {pub_key, priv_key} = :crypto.generate_key(:ecdh, :secp256k1, key)

    Agent.update(:wallet, fn store ->
      Map.put(store, Map.size(store) + 1, %WalletAccount{pub_key: pub_key, priv_key: priv_key})
    end)

    sync_to_disk()
  end

  @doc """
  Loads the accounts from the local wallet file. 
  """
  def load_from_disk() do
    file_path = SimpleBlockchain.get_local_wallet_file()
    data = File.read!(file_path) |> JSON.decode() |> elem(1)

    Enum.each(data, fn [id, pub, priv] ->
      Agent.update(:wallet, fn store ->
        Map.put(store, id, %WalletAccount{
          pub_key: Base.decode64(pub) |> elem(1),
          priv_key: Base.decode64(priv) |> elem(1)
        })
      end)
    end)
  end

  @doc """
  Saves the account to the local wallet file. 
  """
  def sync_to_disk() do
    file_path = SimpleBlockchain.get_local_wallet_file()
    file = File.open!(file_path, [:write, :utf8])

    data =
      Agent.get(:wallet, fn store -> store end)
      |> Enum.map(fn {id, %WalletAccount{pub_key: pub, priv_key: priv}} ->
        [id] ++ Enum.map([pub, priv], &Base.encode64/1)
      end)
      |> JSON.encode()
      |> elem(1)

    IO.write(file, data)
  end

  @doc """
  Retrieve a list of stored accounts.
  Each account has an user friendly id which we can use to interface with the module. 
  """
  def list_accounts() do
    Agent.get(:wallet, fn store -> store end)
    |> Enum.map(fn {id, %WalletAccount{pub_key: pub, priv_key: _}} ->
      {id, Base.encode64(pub)}
    end)
  end

  @doc """
  Aplies a function fun/1 to the account with id num. 
  """
  def apply_for_account_num(num, fun) do
    case Agent.get(:wallet, fn store -> Map.get(store, num) end) do
      nil -> {:error, :unknown_wallet}
      a -> fun.(a)
    end
  end

  @doc """
  Retrieves the available funds for to the account with id num. 
  """
  def get_funds_for(num) do
    apply_for_account_num(num, fn %WalletAccount{pub_key: pub} ->
      {:ok, AccountStore.get_available_funds(pub)}
    end)
  end

  @doc """
  Creates a transfer from account with id num_from to account with id num_to.
  The transfer will be for amount tokens with a specified transaction fee 
  """
  def transfer_between_my_accounts(num_from, num_to, amount, fee \\ 100) do
    apply_for_account_num(num_to, fn %WalletAccount{pub_key: pub} ->
      transfer_funds(num_from, pub, amount, fee)
    end)
  end

  @doc """
  Creates a transfer from account with id num_from to account with public key dest.
  The transfer will be for amount tokens with a specified transaction fee 
  """
  def transfer_funds(num, dest, amount, fee \\ 100) do
    apply_for_account_num(num, fn from ->
      WalletAccount.transfer(from, dest, amount, fee)
    end)
  end

  @doc """
  Starts mining with the account with id num.
  Setting native? to true enables the native miner(WIP) 
  """
  def start_mining_for(num, native? \\ false) do
    apply_for_account_num(num, fn account ->
      Miner.mine_forever(
        WalletAccount.get_details_for_receiving_mining_rewards(account),
        native?
      )
    end)
  end
end
