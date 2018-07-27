defmodule TransactionPool do
  @moduledoc """
  Documentation for TransactionPool.
  This module encapsulates the uncorfirmed transactions and provides an API to register new transactions and retrieve pending transactions
  """

  @doc """
  Starts the transaction pool
  Started alongside SimpleBlockchain
  """
  def start_link() do
    case Agent.start_link(fn -> %{} end) do
      {:ok, pid} -> Process.register(pid, :pool)
      {:error, _} -> raise "Could not start transactions pool"
    end
  end

  # doc
  # Helper for registering a verified pending transaction
  #
  defp internal_register_verified_transaction(transaction) do
    hash = Transaction.hash(transaction)
    Agent.update(:pool, fn pool -> Map.put(pool, hash, transaction) end)
    {:ok, :registered}
  end

  # doc
  # After a new block was included in the blockchain check which transactions are definitely invalid.
  #
  defp reverify_pool() do
    Agent.get(:pool, fn pool -> pool end)
    |> Enum.each(fn {transaction_hash, transaction} ->
      case AccountStore.verify_transaction_body(transaction.body) do
        :ok ->
          :ok

        {:error, _} ->
          Agent.update(:pool, fn pool ->
            Map.delete(pool, transaction_hash)
          end)
      end
    end)
  end

  @doc """
  Returns the uncorfirmed transactions as a map from the transaction_hash to the transaction itselt
  """
  def get_mineable_transactions() do
    Agent.get(:pool, fn pool -> pool end)
  end

  @doc """
  After a new block was included in the blockchain removes the newly confirmed transactions from the pool
  """
  def remove_confirmed_transactions(transaction_list) do
    Enum.each(transaction_list, fn t ->
      hash = Transaction.hash(t)
      Agent.update(:pool, fn pool -> Map.delete(pool, hash) end)
    end)

    reverify_pool()
  end

  @doc """
  Registers a new transaction
  """
  def register_new_transaction(transaction) do
    # Don't register an invalid transaction
    case Transaction.verify_signature(transaction) do
      :ok ->
        case AccountStore.verify_transaction_body(transaction.body) do
          :ok -> internal_register_verified_transaction(transaction)
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
