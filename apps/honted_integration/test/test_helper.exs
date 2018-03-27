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

# because we want to use mix test --no-start by default
[:porcelain, :hackney]
|> Enum.map(&Application.ensure_all_started/1)

ExUnit.configure(exclude: [integration: true])
ExUnitFixtures.start()
ExUnitFixtures.load_fixture_files() # need to do this in umbrella apps
ExUnit.start()
