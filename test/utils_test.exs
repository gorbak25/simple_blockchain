defmodule UtilsTest do
  use ExUnit.Case
  doctest Utils

  test "Properly serializes lists" do
    list = ["A", "B", "C", "D", "E", "F", "G"]
    serialized = Utils.serialize_list(list, fn i -> i end)
    deserialized = Utils.unserialize_list(serialized, &String.next_codepoint/1)
    assert elem(deserialized, 1) == ""
    assert elem(deserialized, 0) == list
  end
end
