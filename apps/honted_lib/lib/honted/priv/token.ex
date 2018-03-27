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

defmodule HonteD.Token do
  @moduledoc """
  Library functions related to handling tokens' data
  """
  def create_address(issuer, nonce) do
    issuer
    |> Kernel.<>(" creates token number ")
    |> Kernel.<>(to_string(nonce))
    |> HonteD.Crypto.hash
    |> Kernel.binary_part(0, 37)
    |> Kernel.<>("tok")
  end
end
