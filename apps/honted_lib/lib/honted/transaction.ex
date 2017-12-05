defmodule HonteD.Transaction do
  @moduledoc """
  Used to manipulate the transaction structures

  # FIXME: sometime let's reduce this boilerplate code that now is spread accross here, tx_codec, api
  #        it's pretty consistent but drying this would be nice, hopefully without complicating too much
  """
  alias HonteD.Transaction.Validation

  defmodule CreateToken do
    @moduledoc false
    defstruct [:nonce, :issuer]

    @type t :: %CreateToken{
      nonce: HonteD.nonce,
      issuer: HonteD.address,
    }
  end

  defmodule Issue do
    @moduledoc false
    defstruct [:nonce, :asset, :amount, :dest, :issuer]

    @type t :: %Issue{
      nonce: HonteD.nonce,
      asset: HonteD.token,
      amount: pos_integer,
      dest: HonteD.address,
      issuer: HonteD.address,
    }
  end

  defmodule Send do
    @moduledoc false
    defstruct [:nonce, :asset, :amount, :from, :to]

    @type t :: %Send{
      nonce: HonteD.nonce,
      asset: HonteD.token,
      amount: pos_integer,
      from: HonteD.address,
      to: HonteD.address,
    }
  end

  defmodule SignOff do
    @moduledoc false
    defstruct [:nonce, :height, :hash, :sender, :signoffer]

    @type t :: %SignOff{
      nonce: HonteD.nonce,
      height: pos_integer,
      hash: HonteD.block_hash,
      sender: HonteD.address,
      signoffer: HonteD.address,
    }
  end

  defmodule Allow do
    @moduledoc false
    defstruct [:nonce, :allower, :allowee, :privilege, :allow]

    @type t :: %Allow{
      nonce: HonteD.nonce,
      allower: HonteD.address,
      allowee: HonteD.address,
      privilege: HonteD.privilege,
      allow: boolean,
    }
  end

  defmodule SignedTx do
    @moduledoc false
    defstruct [:raw_tx, :signature]

    @type t :: %SignedTx{
      raw_tx: HonteD.Transaction.t,
      signature: HonteD.signature
    }
  end

  @type t :: CreateToken.t | Issue.t | Send.t | SignOff.t | Allow.t

  @doc """
  Creates a CreateToken transaction, ensures state-less validity and encodes
  """
  @spec create_create_token([nonce: HonteD.nonce, issuer: HonteD.address]) ::
    {:ok, CreateToken.t} | {:error, atom}
  def create_create_token([nonce: nonce, issuer: issuer] = args)
  when is_integer(nonce) and
       is_binary(issuer) do
    create_encoded(CreateToken, args)
  end

  @doc """
  Creates a Issue transaction, ensures state-less validity and encodes
  """
  @spec create_issue([nonce: HonteD.nonce,
                      asset: HonteD.token,
                      amount: pos_integer,
                      dest: HonteD.address,
                      issuer: HonteD.address]) ::
    {:ok, Issue.t} | {:error, atom}
  def create_issue([nonce: nonce,
                    asset: asset,
                    amount: amount,
                    dest: dest,
                    issuer: issuer] = args)
  when is_integer(nonce) and
       is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(issuer) and
       is_binary(dest) do
    create_encoded(Issue, args)
  end

  @doc """
  Creates a Send transaction, ensures state-less validity and encodes
  """
  @spec create_send([nonce: HonteD.nonce,
                     asset: HonteD.token,
                     amount: pos_integer,
                     from: HonteD.address,
                     to: HonteD.address]) ::
    {:ok, Send.t} | {:error, atom}
  def create_send([nonce: nonce,
                   asset: asset,
                   amount: amount,
                   from: from,
                   to: to] = args)
  when is_integer(nonce) and
       is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(from) and
       is_binary(to) do
    create_encoded(Send, args)
  end

  @doc """
  Creates a SignOff transaction, ensures state-less validity and encodes
  """
  @spec create_sign_off([nonce: HonteD.nonce,
                         height: HonteD.block_height,
                         hash: HonteD.block_hash,
                         sender: HonteD.address,
                         signoffer: HonteD.address]) ::
    {:ok, SignOff.t} | {:error, atom}
  def create_sign_off([nonce: nonce,
                       height: height,
                       hash: hash,
                       sender: sender,
                       signoffer: signoffer] = args)
  when is_integer(nonce) and
       is_integer(height) and
       height > 0 and
       is_binary(hash) and
       is_binary(sender) and
       is_binary(signoffer) do
    create_encoded(SignOff, args)
  end
  def create_sign_off([nonce: _, height: _, hash: _, sender: sender] = args) do
    args
    |> Keyword.merge([signoffer: sender])
    |> create_sign_off
  end

  @doc """
  Creates an Allow transaction, ensures state-less validity and encodes
  """
  @spec create_allow([nonce: HonteD.nonce,
                      allower: HonteD.address,
                      allowee: HonteD.address,
                      privilege: HonteD.privilege,
                      allow: boolean]) ::
    {:ok, Allow.t} | {:error, atom}
  def create_allow([nonce: nonce,
                    allower: allower,
                    allowee: allowee,
                    privilege: privilege,
                    allow: allow] = args)
  when is_integer(nonce) and
       is_binary(allower) and
       is_binary(allowee) and
       is_binary(privilege) and
       is_boolean(allow) do
    create_encoded(Allow, args)
  end

  defp create_encoded(type, args) do
    with tx <- struct(type, args),
         :ok <- Validation.valid?(tx),
         do: {:ok, HonteD.TxCodec.encode(tx)}
  end
end
