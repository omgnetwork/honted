defmodule HonteD.Crypto do
  @moduledoc """
  Signs and validates signatures. Constructed signatures can be used directly
  in Ethereum with `ecrecover` call.

  """

  @doc """
  Produces a cryptographic digest of a message.

  TODO: replace hashing function with ethereum's Keccak
  """
  def hash(message), do: message |> erlang_hash()

  # NOTE temporary function, which will go away when we move to sha3 and eth primitives
  defp erlang_hash(message), do: :crypto.hash(:sha256, message)

  @doc """
  Produce a stand-alone signature for message of arbitrary length. (r,s,v) tuple, 65 bytes long.
  """
  def signature(msg, priv) do
    msg
    |> hash()
    |> signature_digest(priv)
  end

  @doc """
  Produces a stand-alone signature for message hash. (r,s,v) tuple, 65 bytes long.
  """
  def signature_digest(digest, priv) when is_binary(digest) and byte_size(digest) == 32 do
    # note that here signature === <<r::integer-size(256), s::integer-size(256)>>
    {signature, _r, _s, v} = ExthCrypto.Signature.sign_digest(digest, priv)
    v = v + 27 # (why 27? see: https://github.com/ethereum/eips/issues/155#issuecomment-253952071)
    <<signature :: binary-size(64), v :: unsigned-big-integer-unit(8)-size(1)>>
    # [r,s,v] <- order of encoding
    # r == signature.r, left-padded with zeroes to 32 bytes
    # s == signature.s, left-padded with zeroes to 32 bytes
    # v == recoveryParam; recoveryParam == 28 or 27; one byte
    # total 65
  end

  @doc """
  Verifies if private key corresponding to `address` was used to produce `signature` for
  this `msg` binary.
  """
  @spec verify(binary, binary, binary) :: {:ok, boolean}
  def verify(msg, signature, address) do
    {:ok, recovered_address} =
      msg |> hash()|> recover(signature)
    {:ok, address == recovered_address}
  end

  @doc """
  Recovers address of signer from binary encoded signature - (r,s,v) tuple.
  """
  @spec recover(binary, binary) :: {:ok, binary}
  def recover(digest, packed_signature) when byte_size(digest) == 32 do
    <<sig :: binary-size(64), v :: unsigned-big-integer-unit(8)-size(1)>> = packed_signature
    {:ok, der_pub} = ExthCrypto.Signature.recover(digest, sig, v-27)
    pub = ExthCrypto.Key.der_to_raw(der_pub)
    generate_address(pub)
  end

  @doc """
  Generates private key. Internally uses OpenSSL RAND_bytes. May throw if there is not enough entropy.
  TODO: Think about moving to something dependent on /dev/urandom instead. Might be less portable.
  """
  def generate_private_key, do: {:ok, :crypto.strong_rand_bytes(32)}

  @doc """
  Given a private key, returns public key.
  """
  @spec generate_public_key(binary) :: {:ok, binary}
  def generate_public_key(priv) when byte_size(priv) == 32 do
    {:ok, der_pub} = ExthCrypto.Signature.get_public_key(priv)
    {:ok, ExthCrypto.Key.der_to_raw(der_pub)}
  end

  @doc """
  Given public key, returns an address.
  """
  @spec generate_address(binary) :: {:ok, binary}
  def generate_address(pub) when byte_size(pub) == 64 do
    <<_ :: binary-size(12), address :: binary-size(20)>> = :keccakf1600.sha3_256(pub)
    {:ok, address}
  end
end
