defmodule HonteDLib.Transaction do
  defmodule CreateToken do
    defstruct [:nonce, :issuer]
    
  end
  
  defmodule Issue do
    defstruct [:nonce, :asset, :amount, :dest, :issuer]
    
  end
  
  defmodule Send do
    defstruct [:nonce, :asset, :amount, :from, :to]
    
  end
  
  defmodule SignedTx do
    defstruct [:raw_tx, :signature]
  end
  
  def with_signature(tx, signature) do
    %SignedTx{raw_tx: tx, signature: signature}
  end
  
  def create_encoded(type, args), do: struct(type, args) |> HonteDLib.TxCodec.encode
end
