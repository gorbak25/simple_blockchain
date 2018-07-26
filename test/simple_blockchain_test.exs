defmodule SimpleBlockchainTest do
  use ExUnit.Case
  doctest SimpleBlockchain

  test "greets the world" do
    assert SimpleBlockchain.hello() == :world
  end
end
