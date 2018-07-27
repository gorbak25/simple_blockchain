defmodule BlockHeader do
  @moduledoc """
  Documentation for BlockHeader.
  This structure represents the block header.
  """

  defstruct [
    :prev_hash,
    {:difficulty, 20},
    {:nonce, 0},

    # let's implement block rewards ;) 
    :miner_pub_key,
    # sign(miner_pub_key, unknown_miner_priv_key)
    :miner_proof_of_priv_key,
    :chain_state_merkle_hash,
    :transactions_merkle_hash
  ]

  @doc """
  Serializes the block header
  """
  def serialize(header) do
    miner_proof_of_priv_key_bit_len = bit_size(header.miner_proof_of_priv_key)

    header.prev_hash <>
      <<header.difficulty::8>> <>
      <<header.nonce::64>> <>
      header.miner_pub_key <>
      <<miner_proof_of_priv_key_bit_len::16>> <>
      header.miner_proof_of_priv_key <>
      header.chain_state_merkle_hash <> header.transactions_merkle_hash
  end

  @doc """
  Creates a BlockHeader from raw binary data. The leftover binary data is returned alongside the new structure.
  """
  def unserialize(data) do
    # TODO: Move the hardcoded lengths to a configuration file... or even create a customizable picler/depicler
    <<
      prev_hash::256,
      difficulty::8,
      nonce::64,
      miner_pub_key::520,
      miner_proof_of_priv_key_bit_len::16,
      rest::binary
    >> = data

    <<
      miner_proof_of_priv_key::size(miner_proof_of_priv_key_bit_len),
      chain_state_merkle_hash::256,
      transactions_merkle_hash::256,
      rest2::bitstring
    >> = rest

    {
      %BlockHeader{
        prev_hash: <<prev_hash::256>>,
        difficulty: difficulty,
        nonce: nonce,
        miner_pub_key: <<miner_pub_key::520>>,
        miner_proof_of_priv_key:
          <<miner_proof_of_priv_key::size(miner_proof_of_priv_key_bit_len)>>,
        chain_state_merkle_hash: <<chain_state_merkle_hash::256>>,
        transactions_merkle_hash: <<transactions_merkle_hash::256>>
      },
      rest2
    }
  end
end
