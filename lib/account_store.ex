defmodule Account do
  @moduledoc """
  Documentation for Account.
  This structure contains the account metadata.
  """
  defstruct amount: 0, spend_nonces: MapSet.new()
end

defmodule AccountStore do
  @moduledoc """
  Documentation for AccountStore.
  This module encapsulates the current state of every account and provided an api to register and verify transactions
  """

  @doc """
  Starts the account store
  Started alongside SimpleBlockchain
  """
  def start_link() do
    case Agent.start_link(fn -> %{} end) do
      {:ok, pid} -> Process.register(pid, :accounts)
      {:error, _} -> raise "Could not start account store"
    end
  end

  # doc
  # Helper for getting an account from a pub key
  #
  defp get_account(pub_key) do
    Agent.get(:accounts, fn store -> Map.get(store, pub_key) end)
  end

  @doc """
  Retrieves the available funds for a given pub_key
  """
  def get_available_funds(pub_key) do
    case get_account(pub_key) do
      nil -> 0
      %Account{amount: amount} -> amount
    end
  end

  # doc
  # Tries to retrieve an account for pub_key. If such account does not exist #create and return a new one.
  #
  defp enforce_account_exists(pub_key) do
    case get_account(pub_key) do
      nil -> %Account{}
      a -> a
    end
  end

  # doc
  # Updates the account for pub_key by aplying fun to it
  #
  defp update_account(pub_key, fun) do
    res = fun.(enforce_account_exists(pub_key))
    Agent.update(:accounts, fn store -> Map.put(store, pub_key, res) end)
  end

  @doc """
  Checks whether the transaction_body is correct
  Returns :ok if the provided data seems valid
  Returns {:error, :reason} if the data is invalid
  """
  def verify_transaction_body(transaction_body) do
    if transaction_body.amount <= 0 or transaction_body.transaction_fee < 0 do
      {:error, :invalid_amount}
    else
      case get_account(transaction_body.from) do
        %Account{amount: amount, spend_nonces: nonces} ->
          cond do
            transaction_body.amount + transaction_body.transaction_fee > amount ->
              {:error, :insufficient_funds}

            MapSet.member?(nonces, transaction_body.nonce) ->
              {:error, :invalid_nonce}

            true ->
              :ok
          end

        nil ->
          {:error, :insufficient_funds}
      end
    end
  end

  @doc """
  Rewards a miner with money
  """
  def reward_miner(miner_pub_key, value) do
    update_account(miner_pub_key, fn account ->
      %Account{account | amount: account.amount + value}
    end)
  end

  @doc """
  Updates the current balances according to a given transaction.
  Before passing a transaction to this function the transaction must be first verified by the verify_transaction_body and the Transaction.verify_signature function
  """
  def register_transaction_body(transaction_body, miner_pub_key) do
    update_account(transaction_body.from, fn account ->
      %Account{
        account
        | amount: account.amount - transaction_body.amount - transaction_body.transaction_fee,
          spend_nonces: MapSet.put(account.spend_nonces, transaction_body.nonce)
      }
    end)

    update_account(transaction_body.to, fn account ->
      %Account{account | amount: account.amount + transaction_body.amount}
    end)

    if transaction_body.transaction_fee > 0 do
      update_account(miner_pub_key, fn account ->
        %Account{account | amount: account.amount + transaction_body.transaction_fee}
      end)
    end
  end
end
