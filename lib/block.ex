defmodule Block do
  @moduledoc """
  Documentation for Block.
  This structure represents a block.
  """

  defstruct [
    :header,
    :body
  ]

  @doc """
  Serializes the block
  """
  def serialize(block) do
    BlockHeader.serialize(block.header) <> BlockBody.serialize(block.body)
  end

  @doc """
  Creates a new Block from raw binary data. The leftover binary data is returned alongside the new structure.
  """
  def unserialize(data) do
    {header, rest} = BlockHeader.unserialize(data)
    {body, rest2} = BlockBody.unserialize(rest)

    {
      %Block{
        header: header,
        body: body
      },
      rest2
    }
  end

  @doc """
  Calculates the hash of a block
  """
  def hash(block) do
    data = Block.serialize(block)
    :crypto.hash(:sha256, data)
  end

  # doc
  # Returns :ok if the miner signature is valid
  # {:error, :invalid_miner_sig} otherwise
  #
  defp verify_miner_signature(block) do
    if :crypto.verify(
         :ecdsa,
         :sha256,
         block.header.miner_pub_key,
         block.header.miner_proof_of_priv_key,
         [block.header.miner_pub_key, :secp256k1]
       ) do
      :ok
    else
      {:error, :invalid_miner_sig}
    end
  end

  @doc """
  Returns :ok if the block contains a valid POW
  {:error, :invalid_pow} otherwise
  """
  def verify_POW(block) do
    difficulty = block.header.difficulty

    case Block.hash(block) do
      <<0::size(difficulty), _::bitstring>> ->
        :ok

      _ ->
        {:error, :invalid_pow}
    end
  end

  @doc """
  Checks whether the given block seems valid.
  Returns :ok if the block seems valid
  {:error, reason} otherwise
  """
  def verify(block) do
    # This would be a job for monads :P
    case verify_POW(block) do
      :ok ->
        case verify_miner_signature(block) do
          :ok ->
            case BlockBody.verify(block.body) do
              :ok -> :ok
              {:error, :reason} -> {:error, :reason}
            end

          {:error, :reason} ->
            {:error, :reason}
        end

      {:error, :reason} ->
        {:error, :reason}
    end
  end

  @doc """
  Returns a new block with increased nonce
  """
  def increase_nonce(block) do
    %Block{block | header: %BlockHeader{block.header | nonce: block.header.nonce + 1}}
  end
end
