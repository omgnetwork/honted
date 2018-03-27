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

defmodule HonteD.Integration.VersionTest do
  @moduledoc """
  Intends to make a quick check whether the binaries available are at their correct versions
  """
  use ExUnit.Case, async: false

  @moduletag :integration

  test "Tendermint at supported version" do
    %Porcelain.Result{err: nil, status: 0, out: version_output} = Porcelain.shell(
      "tendermint version"
    )
    version_output
    |> String.trim
    |> Version.match?("~> 0.15")
    |> assert
  end
end
