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

defmodule HonteD.Integration.Performance.TMBench do
  @moduledoc """
  Handling of the tm_bench facility from tendermint/tools
  """

  alias HonteD.Integration

  @doc """
  Starts a tm-bench Porcelain process for `duration` to listen for events and collect metrics
  """
  def start_for(duration) do
    # start the benchmarking tool and capture the stdout
    tm_bench_proc = %Porcelain.Process{err: nil, out: tm_bench_out} = Porcelain.spawn_shell(
      "tm-bench -c 0 -T #{duration} localhost:46657",
      out: :stream
    )
    :ok = wait_for_tm_bench_start(tm_bench_out)

    {tm_bench_proc, tm_bench_out}
  end

  defp wait_for_tm_bench_start(tm_bench_out) do
    Integration.wait_for_start(tm_bench_out, "Running ", 1000)
  end

  def finalize_output(tm_bench_out) do
    tm_bench_out
    |> Enum.to_list
    |> Enum.join
  end
end
