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

defmodule HonteD.Integration.Fixtures do
  use ExUnitFixtures.FixtureModule

  alias HonteD.Integration

  deffixture homedir() do
    Integration.homedir()
  end

  deffixture tendermint(homedir, honted) do
    :ok = honted # prevent warnings
    {:ok, exit_fn} = Integration.tendermint(homedir)
    on_exit exit_fn
    :ok
  end

  deffixture honted() do
    {:ok, exit_fn} = Integration.honted()
    on_exit exit_fn
    :ok
  end

  deffixture geth() do
    {:ok, exit_fn} = Integration.geth()
    on_exit exit_fn
    :ok
  end

end
