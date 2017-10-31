defmodule HonteDLib.Transaction do
  @moduledoc """
  Used to manipulate the transaction structures
  """
  alias HonteDLib.Transaction.Validation
  
  @type t :: CreateToken.t | Issue.t | Send.t
  
  defmodule CreateToken do
    defstruct [:nonce, :issuer]
    
    @type t :: %CreateToken{
      nonce: HonteDLib.nonce,
      issuer: HonteDLib.address,
    }
  end
  
  defmodule Issue do
    defstruct [:nonce, :asset, :amount, :dest, :issuer]
    
    @type t :: %Issue{
      nonce: HonteDLib.nonce,
      asset: HonteDLib.address,
      amount: pos_integer,
      dest: HonteDLib.address,
      issuer: HonteDLib.address,
    }
  end
  
  defmodule Send do
    defstruct [:nonce, :asset, :amount, :from, :to]
    
    @type t :: %Send{
      nonce: HonteDLib.nonce,
      asset: HonteDLib.address,
      amount: pos_integer,
      from: HonteDLib.address,
      to: HonteDLib.address,
    }
  end
  
  defmodule SignedTx do
    defstruct [:raw_tx, :signature]
    
    @type t :: %SignedTx{
      raw_tx: HonteDLib.Transaction.t,
      signature: HonteDLib.signature
    }
  end
  
  @doc """
  Creates a CreateToken transaction, ensures state-less validity and encodes
  """
  @spec create_create_token([nonce: HonteDLib.nonce, issuer: HonteDLib.address]) :: 
    {:ok, CreateToken.t} | {:error, atom}
  def create_create_token([nonce: nonce, issuer: issuer] = args)
  when is_integer(nonce) and
       is_binary(issuer) do
    create_encoded(CreateToken, args)
  end
  
  @doc """
  Creates a Issue transaction, ensures state-less validity and encodes
  """
  @spec create_issue([nonce: HonteDLib.nonce, asset: HonteDLib.address, amount: pos_integer, dest: HonteDLib.address, issuer: HonteDLib.address]) :: 
    {:ok, Issue.t} | {:error, atom}
  def create_issue([nonce: nonce, asset: asset, amount: amount, dest: dest, issuer: issuer] = args)
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
  @spec create_send([nonce: HonteDLib.nonce, asset: HonteDLib.address, amount: pos_integer, from: HonteDLib.address, to: HonteDLib.address]) :: 
    {:ok, Send.t} | {:error, atom}
  def create_send([nonce: nonce, asset: asset, amount: amount, from: from, to: to] = args)
  when is_integer(nonce) and
       is_binary(asset) and
       is_integer(amount) and
       amount > 0 and
       is_binary(from) and
       is_binary(to) do
    create_encoded(Send, args)
  end
  
  defp create_encoded(type, args) do
    with tx <- struct(type, args),
         :ok <- Validation.valid?(tx),
         do: {:ok, HonteDLib.TxCodec.encode(tx)}
  end
end
