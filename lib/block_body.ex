defmodule BlockBody do
  @moduledoc """
  Documentation for BlockBody.
  This structure represents the block body.
  """

  defstruct transactions: []

  @doc """
  Serializes the block body
  """
  def serialize(body) do
    Utils.serialize_list(body.transactions, &Transaction.serialize/1)
  end

  @doc """
  Creates a BlockBody from raw binary data. The leftover binary data is returned alongside the new structure.
  """
  def unserialize(data) do
    {list, rest} = Utils.unserialize_list(data, &Transaction.unserialize/1)

    {
      %BlockBody{
        transactions: list
      },
      rest
    }
  end

  @doc """
  Verifies whether the block_body is valid.
  Returns :ok if the block_body is correct, {:error, reason} otherwise.
  """
  def verify(block_body) do
    if length(block_body.transactions) > 100 do
      {:error, :too_many_transactions_in_a_block}
    else
      Enum.reduce_while(block_body.transactions, :ok, fn trans, _ ->
        case Transaction.verify_signature(trans) do
          :ok ->
            case AccountStore.verify_transaction_body(trans.body) do
              :ok -> {:cont, :ok}
              err -> {:halt, err}
            end

          err ->
            {:halt, err}
        end
      end)
    end
  end
end
