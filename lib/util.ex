defmodule Utils do
  @moduledoc """
  Documentation for Utils.
  This module provides helpers for the project.
  """

  @doc """
  Serialized the list to a binary format. Every element in the list will be encoded with the encode_fun function
  """
  def serialize_list(list, encode_fun) do
    # IO.inspect list
    {list_len, serialized_list} =
      Enum.reduce(
        list,
        {0, <<>>},
        fn cur, {len, data} ->
          {
            len + 1,
            encode_fun.(cur) <> data
          }
        end
      )

    <<list_len::64>> <> serialized_list
  end

  @doc """
  Appends to a file containing a single list serialized via the Utils.serialize_list/2 function a new element of the list. The newly appended element will be at the head of the deserialized list.
  """
  def append_to_list_file(data, file) do
    if File.regular?(file) do
      # Time for erlang :P
      # TODO: throw a proper exception
      {:ok, f} = :file.open(file, [:binary, :write, :read])
      :file.pwrite(f, {:eof, 0}, data)
      {:ok, <<list_len::64>>} = :file.pread(f, 0, 8)
      :file.pwrite(f, 0, <<list_len + 1::64>>)
      :file.close(f)
    else
      IO.inspect([data])
      to_write = serialize_list([data], fn id -> id end)

      File.open!(file, [:write, :binary])
      |> IO.binwrite(to_write)
    end
  end

  # doc
  # Helper for unserializing a list
  #
  defp internal_unserialize_list(data, n, _) when n === 0 do
    {[], data}
  end

  # doc
  # Helper for unserializing a list
  #
  defp internal_unserialize_list(data, n, decode_fun) do
    {cur, rest} = decode_fun.(data)
    {tail, remaining_data} = internal_unserialize_list(rest, n - 1, decode_fun)
    {[cur] ++ tail, remaining_data}
  end

  @doc """
  Unserializes a list from binary data acording to a decoder.
  The decode_fun/1 function must return a tuple containing the newly deserialized list entry and the leftover binary data.
  This function returns a tuple containing the resulting list and the leftover unserialized data.
  """
  def unserialize_list(data, decode_fun) do
    <<
      list_len::64,
      rest::binary
    >> = data

    {res, remaining} = internal_unserialize_list(rest, list_len, decode_fun)
    {Enum.reverse(res), remaining}
  end
end
