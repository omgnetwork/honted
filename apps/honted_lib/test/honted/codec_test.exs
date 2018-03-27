#   Copyright 2018 OmiseGO Pte Ltd
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

defmodule HonteD.TxCodecTest do
  use ExUnit.Case, async: true
  @moduledoc """
  """

  @moduletag :codec

  alias HonteD.Crypto

  test "encode for signed" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    {:ok, tx} = HonteD.Transaction.create_create_token(nonce: 1, issuer: address)
    tx
    |> HonteD.TxCodec.encode()
    |> Base.encode16()
    |> HonteD.Transaction.sign(priv)
  end

  test "encode/decode for unsigned" do
    {:ok, priv} = Crypto.generate_private_key
    {:ok, pub} = Crypto.generate_public_key(priv)
    {:ok, address} = Crypto.generate_address(pub)

    {:ok, tx} = HonteD.Transaction.create_create_token(nonce: 1, issuer: address)
    enc = HonteD.TxCodec.encode(tx)
    assert {:ok, ^tx} = HonteD.TxCodec.decode(enc)
  end

end
