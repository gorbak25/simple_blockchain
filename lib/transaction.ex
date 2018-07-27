defmodule TransactionBody do
  @moduledoc """
  Documentation for TransactionBody.
  This structure contains the body of a single transaction.
  """

  defstruct [
    :from,
    :to,
    :amount,
    # not specified in the specification but necessary in order to avoid replay attacks. What would stop Bob from resubmiting valid transactions?
    :nonce,
    # let's get fancy
    :transaction_fee
  ]

  @doc """
  Serializes the transaction body
  """
  def serialize(body) do
    body.from <>
      body.to <> <<body.amount::64>> <> <<body.nonce::64>> <> <<body.transaction_fee::64>>
  end

  @doc """
  Creates a new TransactionBody from raw binary data. The leftover binary data is returned alongside the new structure.
  """
  def unserialize(data) do
    <<
      from::520,
      to::520,
      amount::64,
      nonce::64,
      transaction_fee::64,
      rest::bitstring
    >> = data

    {
      %TransactionBody{
        from: <<from::520>>,
        to: <<to::520>>,
        amount: amount,
        nonce: nonce,
        transaction_fee: transaction_fee
      },
      rest
    }
  end
end

defmodule Transaction do
  @moduledoc """
  Documentation for Transaction.
  This structure contains a single transaction.
  """

  defstruct [
    :body,
    :signature
  ]

  @doc """
  Serializes the transaction
  """
  def serialize(trans) do
    TransactionBody.serialize(trans.body) <> <<bit_size(trans.signature)::16>> <> trans.signature
  end

  @doc """
  Creates a new Transaction from raw binary data. The leftover binary data is returned alongside the new structure.
  """
  def unserialize(data) do
    {body, rest} = TransactionBody.unserialize(data)
    <<signature_len::16, rest2::binary>> = rest
    <<signature::size(signature_len), rest3::binary>> = rest2

    {%Transaction{
       body: body,
       signature: <<signature::size(signature_len)>>
     }, rest3}
  end

  @doc """
  Return :ok if the provided transaction contains a valid signature
  returns {:error, :invalid_sig} otherwise
  """
  def verify_signature(trans) do
    signed_data = TransactionBody.serialize(trans.body)

    if :crypto.verify(:ecdsa, :sha256, signed_data, trans.signature, [trans.body.from, :secp256k1]) do
      :ok
    else
      {:error, :invalid_sig}
    end
  end

  @doc """
  Calculates the hash of the transaction
  """
  def hash(transaction) do
    data = serialize(transaction)
    :crypto.hash(:sha256, data)
  end

  @doc """
  Retrieves the transaction fee for the transaction
  """
  def get_transaction_fee(%Transaction{body: %TransactionBody{transaction_fee: transaction_fee}}) do
    transaction_fee
  end
end
