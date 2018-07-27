defmodule SimpleBlockchain do
  @moduledoc """
  Documentation for SimpleBlockchain.
  This module encapsulates the state of the blockchain and provides an API
  for registering newly mined blocks. The blockchain is stored as a file on the hard drive.
  """

  @doc """
  Starts the block store and related stores
  """
  def start_link() do
    case Agent.start_link(fn -> {0, []} end) do
      {:ok, pid} ->
        Process.register(pid, :blockchain)
        AccountStore.start_link()
        load_local_blockchain()
        # TODO: load_new_blocks_from_remote_nodes
        TransactionPool.start_link()
        Wallet.start_link()

      {:error, _} ->
        raise "Could not start blockchain store"
    end
  end

  # doc
  # Retrieves the app config directory 
  #
  defp get_node_config_dir() do
    case System.get_env("NODE_STORE") do
      # TODO: support windows
      nil ->
        "./.simple_blockchain/"

      s ->
        s
    end
  end

  # doc
  # Sets a given blockchain as the current 
  #
  defp set_new_blockchain({size, blocks}) do
    Agent.update(:blockchain, fn _ -> {size, blocks} end)
  end

  @doc """
  Retrieves the location of the block database 
  """
  def get_local_blockchain_file() do
    conf_dir = get_node_config_dir()
    conf_dir |> Path.join("db") |> Path.join("blockchain.db")
  end

  @doc """
  Retrieves the location of the wallet file 
  """
  def get_local_wallet_file() do
    conf_dir = get_node_config_dir()
    conf_dir |> Path.join("wallet.dat")
  end

  # doc
  # Deserializes the blockchain database 
  #
  defp unserialize_blockchain_file(data) do
    {blocks, <<>>} = Utils.unserialize_list(data, &Block.unserialize/1)
    blocks
  end

  # doc
  # During startup loads and registers the local blockchain present on the #computer. 
  #
  defp load_local_blockchain() do
    conf_dir = get_node_config_dir()
    File.mkdir_p!(Path.join(conf_dir, "db"))
    db_path = conf_dir |> Path.join("db") |> Path.join("blockchain.db")

    if File.regular?(db_path) do
      File.open!(db_path, [:binary, :read])
      |> IO.binread(:all)
      |> unserialize_blockchain_file
      |> verify_and_register_local_blockchain
      |> set_new_blockchain
    end
  end

  # doc
  # Calculates the block reward at bloch height n. 
  #
  defp get_block_reward_for(n) do
    base_reward = 5_000_000
    reduce_after = 1000
    h = div(n, reduce_after)
    div(base_reward, trunc(:math.pow(2, h)))
  end

  # doc
  # Called during startup when the local block database is corrupted. 
  #
  defp fail_unrecoverable_on_block(block, reason) when is_atom(reason) do
    IO.puts(
      :stderr,
      "Verification of localy stored trusted block with hash ##{Base.encode16(Block.hash(block))} failed. Reason: #{
        to_string(reason)
      }"
    )

    raise "error"
  end

  # doc
  # Processes an verified block of height n and updated account balances accordingly 
  #
  defp register_verified_block(block, n) do
    Enum.each(block.body.transactions, fn trans ->
      AccountStore.register_transaction_body(trans.body, block.header.miner_pub_key)
    end)

    reward = get_block_reward_for(n)
    AccountStore.reward_miner(block.header.miner_pub_key, reward)
  end

  # doc
  # Verifies the correctness of the genesis block. 
  #
  defp verify_single_local_block(block, {prev_hash, n}) when prev_hash === :genesis do
    cur_hash = Block.hash(block)

    if block.header.prev_hash !== :crypto.hash(:sha256, "GENESIS") do
      fail_unrecoverable_on_block(block, :corrupted_genesis_block)
    end

    # Hardcoded genesis block
    # IO.inspect(Base.encode16(cur_hash))
    if Base.encode16(cur_hash) !=
         "000003D7FFFEF8ECDCDC56378855C9717343D395E5CA5E7EF14F39A81CCC1CA9" do
      fail_unrecoverable_on_block(block, :unknown_genesis_block)
    end

    register_verified_block(block, n)
    {cur_hash, n + 1}
  end

  # doc
  # Verifies the correctness of a block found in the local block database file. 
  #
  defp verify_single_local_block(block, {prev_hash, n}) do
    if block.header.prev_hash != prev_hash,
      do: fail_unrecoverable_on_block(block, :corrupted_chain)

    case Block.verify(block) do
      {:error, reason} -> fail_unrecoverable_on_block(block, reason)
      _ -> :ok
    end

    register_verified_block(block, n)
    {Block.hash(block), n + 1}
  end

  # doc
  # During startup verifies and registers the correctness of the local blockchain. 
  #
  defp verify_and_register_local_blockchain(blockchain) do
    blocks = Enum.reverse(blockchain)
    {_, n} = Enum.reduce(blocks, {:genesis, 1}, &verify_single_local_block/2)
    {n, blockchain}
  end

  @doc """
  Returns the hash of the most recent block. 
  """
  def get_newest_block_hash() do
    Agent.get(:blockchain, fn b ->
      case b do
        {_, []} -> :crypto.hash(:sha256, "GENESIS")
        {_, [h | _]} -> Block.hash(h)
      end
    end)
  end

  @doc """
  Returns the current mining difficulty. 
  """
  def get_current_difficulty() do
    # TODO: implement an algorithm in order to create one block every 5 minutes
    # For now just hardcode it at 20
    20
  end

  # doc
  # Appends a block to the local block database. 
  #
  defp append_block_to_local_blockchain_file(block) do
    Utils.append_to_list_file(block, get_local_blockchain_file())
  end

  # doc
  # Appends a block to the blockchain and stores it on disk. 
  #
  defp append_block_to_blockchain(block) do
    Agent.update(:blockchain, fn {size, blockchain} -> {size + 1, [block | blockchain]} end)
    append_block_to_local_blockchain_file(Block.serialize(block))
  end

  # doc
  # Registers a verified newly mined block. 
  #
  defp register_verified_mined_block(block) do
    append_block_to_blockchain(block)
    cur_size = Agent.get(:blockchain, fn {size, _} -> size end)
    register_verified_block(block, cur_size)
    TransactionPool.remove_confirmed_transactions(block.body.transactions)
  end

  @doc """
  Registers a newly mined block in the systems.
  Returns :ok on success
  Returns {:error, reason} uppon failure to verify the provided block 
  """
  def register_mined_block(block) do
    if get_newest_block_hash() != block.header.prev_hash do
      {:error, :invalid_prev_block}
    else
      if block.header.difficulty != get_current_difficulty() do
        {:error, :invalid_difficulty}
      else
        case Block.verify(block) do
          {:error, reason} -> {:error, reason}
          :ok -> register_verified_mined_block(block)
        end
      end
    end
  end
end
