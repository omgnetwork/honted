#The MIT License (MIT)
#Copyright © 2017 Geoffrey Hayes, Ayrat Badykov, Mason Forest
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software
#and associated documentation files (the “Software”), to deal in the Software without restriction,
#including without limitation the rights to use, copy, modify, merge, publish, distribute,
#sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
#subject to the following conditions:
#The above copyright notice and this permission notice shall be included in all copies or substantial
# portions of the Software.
#THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

defmodule HonteD.ABCI.Ethereum.BlockHeader do
  @moduledoc """
  This structure codifies the header of a block in the blockchain.
  """
  # credo:disable-for-this-file Credo.Check.Readability.MaxLineLength
  # credo:disable-for-this-file Credo.Check.Refactor.FunctionArity
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @empty_keccak [] |> ExRLP.encode |> :keccakf1600.sha3_256

  defstruct [
    parent_hash: nil,                # Hp P(BH)Hr
    ommers_hash: @empty_keccak,      # Ho KEC(RLP(L∗H(BU)))
    beneficiary: nil,                # Hc
    state_root: <<0 :: 256>>,        # Hr TRIE(LS(Π(σ, B)))
    transactions_root: <<0 :: 256>>, # Ht TRIE({∀i < kBTk, i ∈ P : p(i, LT (BT[i]))})
    receipts_root: <<0 :: 256>>,     # He TRIE({∀i < kBRk, i ∈ P : p(i, LR(BR[i]))})
    logs_bloom: <<0 :: 2048>>,       # Hb bloom
    difficulty: nil,                 # Hd
    number: nil,                     # Hi
    gas_limit: 0,                    # Hl
    gas_used: 0,                     # Hg
    timestamp: nil,                  # Hs
    extra_data: <<>>,                # Hx
    mix_hash: nil,                   # Hm
    nonce: nil,                      # Hn
  ]

  @type hash :: <<_ :: 256>>
  @type address :: <<_ :: 160>>

  # As defined in Eq.(35)
  @type t :: %__MODULE__{
    parent_hash: hash,
    ommers_hash: hash,
    beneficiary: address,
    state_root: hash,
    transactions_root: hash,
    receipts_root: hash,
    logs_bloom: binary(),
    difficulty: integer() | nil,
    number: integer() | nil,
    gas_limit: integer(),
    gas_used: integer(),
    timestamp: integer() | nil,
    extra_data: binary(),
    mix_hash: hash | nil,
    nonce: <<_ :: 64>> | nil,
  }

  # The start of the Homestead block, as defined in Eq.(13) of the Yellow Paper (N_H)
  @homestead_block 1_150_000

  @initial_difficulty 131_072 # d_0 from Eq.(40)
  @minimum_difficulty @initial_difficulty # Mimics d_0 in Eq.(39), but variable on different chains
  @difficulty_bound_divisor 2048
  @max_extra_data_bytes 32 # Eq.(58)

  @gas_limit_bound_divisor 1024 # Constant from Eq.(45) and Eq.(46)
  @min_gas_limit 125_000 # Eq.(47)

  @doc """
  Returns the block that defines the start of Homestead.
  This should be a constant, but it's configurable on different
  chains, and as such, as allow you to pass that configuration
  variable (which ends up making this the identity function, if so).
  """
  @spec homestead(integer()) :: integer()
  def homestead(homestead_block \\ @homestead_block), do: homestead_block

  @doc """
  This functions encode a header into a value that can
  be RLP encoded. This is defined as L_H Eq.(32) in the Yellow Paper.
  ## Examples
      iex> Block.Header.serialize(%Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>})
      [<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, 5, 1, 5, 3, 6, "Hi mom", <<7::256>>, <<8::64>>]
  """
  @spec serialize(t) :: ExRLP.t
  def serialize(h) do
    [
      h.parent_hash,
      h.ommers_hash,
      h.beneficiary,
      h.state_root,
      h.transactions_root,
      h.receipts_root,
      h.logs_bloom,
      h.difficulty,
      (if h.number == 0, do: <<>>, else: h.number),
      h.gas_limit,
      (if h.number == 0, do: <<>>, else: h.gas_used),
      h.timestamp,
      h.extra_data,
      h.mix_hash,
      h.nonce
    ]
  end

  @doc """
  Deserializes a block header from an RLP encodable structure.
  This effectively undoes the encoding defined in L_H Eq.(32) of the
  Yellow Paper.
  ## Examples
      iex> Block.Header.deserialize([<<1::256>>, <<2::256>>, <<3::160>>, <<4::256>>, <<5::256>>, <<6::256>>, <<>>, <<5>>, <<1>>, <<5>>, <<3>>, <<6>>, "Hi mom", <<7::256>>, <<8::64>>])
      %Block.Header{parent_hash: <<1::256>>, ommers_hash: <<2::256>>, beneficiary: <<3::160>>, state_root: <<4::256>>, transactions_root: <<5::256>>, receipts_root: <<6::256>>, logs_bloom: <<>>, difficulty: 5, number: 1, gas_limit: 5, gas_used: 3, timestamp: 6, extra_data: "Hi mom", mix_hash: <<7::256>>, nonce: <<8::64>>}
  """
  @spec deserialize(ExRLP.t) :: t
  def deserialize(rlp) do
    [
      parent_hash,
      ommers_hash,
      beneficiary,
      state_root,
      transactions_root,
      receipts_root,
      logs_bloom,
      difficulty,
      number,
      gas_limit,
      gas_used,
      timestamp,
      extra_data,
      mix_hash,
      nonce
    ] = rlp

    %__MODULE__{
      parent_hash: parent_hash,
      ommers_hash: ommers_hash,
      beneficiary: beneficiary,
      state_root: state_root,
      transactions_root: transactions_root,
      receipts_root: receipts_root,
      logs_bloom: logs_bloom,
      difficulty: :binary.decode_unsigned(difficulty),
      number: :binary.decode_unsigned(number),
      gas_limit: :binary.decode_unsigned(gas_limit),
      gas_used: :binary.decode_unsigned(gas_used),
      timestamp: :binary.decode_unsigned(timestamp),
      extra_data: extra_data,
      mix_hash: mix_hash,
      nonce: nonce,
    }
  end

  @doc """
  Computes hash of a block header, which is simply the hash of the serialized block header.
  This is defined in Eq.(37) of the Yellow Paper.
  """
  @spec hash(t) :: hash
  def hash(header) do
    header |> serialize() |> ExRLP.encode |> :keccakf1600.sha3_256()
  end

  @doc """
  Returns true if a given block is before the
  Homestead block.
  """
  @spec is_before_homestead?(t, integer()) :: boolean()
  def is_before_homestead?(h, homestead_block \\ @homestead_block) do
    h.number < homestead_block
  end

  @doc """
  Returns true if a given block is at or after the
  Homestead block.
  """
  @spec is_after_homestead?(t, integer()) :: boolean()
  def is_after_homestead?(h, homestead_block \\ @homestead_block), do: not is_before_homestead?(h, homestead_block)

  @doc """
  Returns true if the block header is valid. This defines
  Eq.(50), Eq.(51), Eq.(52), Eq.(53), Eq.(54), Eq.(55),
  Eq.(56), Eq.(57) and Eq.(58) of the Yellow Paper, commonly
  referred to as V(H).
  """
  @spec is_valid?(t, t | nil, integer(), integer(), integer(), integer(), integer(), integer()) :: :valid | {:invalid, [atom()]}
  def is_valid?(header, parent_header, homestead_block \\ @homestead_block, initial_difficulty \\ @initial_difficulty, minimum_difficulty \\ @minimum_difficulty, difficulty_bound_divisor \\ @difficulty_bound_divisor, gas_limit_bound_divisor \\ @gas_limit_bound_divisor, min_gas_limit \\ @min_gas_limit) do
    parent_gas_limit = if parent_header, do: parent_header.gas_limit, else: nil

    errors = [] ++
      (if header.difficulty == get_difficulty(header, parent_header, initial_difficulty, minimum_difficulty, difficulty_bound_divisor, homestead_block), do: [], else: [:invalid_difficulty]) ++ # Eq.(51)
      (if header.gas_used <= header.gas_limit, do: [], else: [:exceeded_gas_limit]) ++ # Eq.(52)
      (if is_gas_limit_valid?(header.gas_limit, parent_gas_limit, gas_limit_bound_divisor, min_gas_limit), do: [], else: [:invalid_gas_limit]) ++ # Eq.(53), Eq.(54) and Eq.(55)
      (if is_nil(parent_header) or header.timestamp > parent_header.timestamp, do: [], else: [:child_timestamp_invalid]) ++ # Eq.(56)
      (if header.number == 0 or header.number == parent_header.number + 1, do: [], else: [:child_number_invalid]) ++ # Eq.(57)
      (if byte_size(header.extra_data) <= @max_extra_data_bytes, do: [], else: [:extra_data_too_large])

    case errors do
      [] -> :valid
      _ -> {:invalid, errors}
    end
  end

  @doc """
  Returns the total available gas left for all transactions in
  this block. This is the total gas limit minus the gas used
  in transactions.
  """
  @spec available_gas(t) :: integer()
  def available_gas(header) do
    header.gas_limit - header.gas_used
  end

  @doc """
  Calculates the difficulty of a new block header. This implements Eq.(39),
  Eq.(40), Eq.(41), Eq.(42), Eq.(43) and Eq.(44) of the Yellow Paper.
  """
  @spec get_difficulty(t, t | nil, integer()) :: integer()
  def get_difficulty(header, parent_header, initial_difficulty \\ @initial_difficulty, minimum_difficulty \\ @minimum_difficulty, difficulty_bound_divisor \\ @difficulty_bound_divisor, homestead_block \\ @homestead_block) do
    cond do
      header.number == 0 -> initial_difficulty
      is_before_homestead?(header, homestead_block) ->
        # Find the delta from parent block
        difficulty_delta = difficulty_x(parent_header.difficulty, difficulty_bound_divisor) * difficulty_s1(header, parent_header) + difficulty_e(header)

        # Add delta to parent block
        next_difficulty = parent_header.difficulty + difficulty_delta

        # Return next difficulty, capped at minimum
        max(minimum_difficulty, next_difficulty)
      true ->
        # Find the delta from parent block (note: we use difficulty_s2 since we're after Homestead)
        difficulty_delta = difficulty_x(parent_header.difficulty, difficulty_bound_divisor) * difficulty_s2(header, parent_header) + difficulty_e(header)

        # Add delta to parent's difficulty
        next_difficulty = parent_header.difficulty + difficulty_delta

        # Return next difficulty, capped at minimum
        max(minimum_difficulty, next_difficulty)
    end
  end

  # Eq.(42) ς1 - Effectively decides if blocks are being mined too quicky or too slower
  @spec difficulty_s1(t, t) :: integer()
  defp difficulty_s1(header, parent_header) do
    if header.timestamp < (parent_header.timestamp + 13), do: 1, else: -1
  end

  # Eq.(43) ς2
  @spec difficulty_s2(t, t) :: integer()
  defp difficulty_s2(header, parent_header) do
    s = floor((header.timestamp - parent_header.timestamp) / 10)
    max(1 - s, -99)
  end

  # Eq.(41) x - Creates some multiplier for how much we should change difficulty based on previous difficulty
  @spec difficulty_x(integer(), integer()) :: integer()
  defp difficulty_x(parent_difficulty, difficulty_bound_divisor), do: floor(parent_difficulty / difficulty_bound_divisor)

  # Eq.(44) ε - Adds a delta to ensure we're increasing difficulty over time
  defp difficulty_e(header) do
    floor(
      :math.pow(
        2,
        floor(header.number / 100_000) - 2
      )
    )
  end

  @spec is_gas_limit_valid?(integer(), integer() | nil) :: boolean()
  def is_gas_limit_valid?(gas_limit, parent_gas_limit, gas_limit_bound_divisor \\ @gas_limit_bound_divisor, min_gas_limit \\ @min_gas_limit) do
    if parent_gas_limit == nil do
      # It's not entirely clear from the Yellow Paper
      # whether a genesis block should have any limits
      # on gas limit, other than min gas limit.
      gas_limit > min_gas_limit
    else
      max_delta = floor(parent_gas_limit / gas_limit_bound_divisor)

      (gas_limit < parent_gas_limit + max_delta) and
      (gas_limit > parent_gas_limit - max_delta) and
      gas_limit > min_gas_limit
    end
  end

  defp floor(x), do: round(:math.floor(x))
end
