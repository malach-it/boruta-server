defmodule BorutaAuth.BlsSignature do
  @moduledoc """
  BLS12-381 minimal-public-key signatures compatible with `phi-crypto`.
  """

  use Rustler, otp_app: :boruta_auth, crate: :phi_crypto_nif

  @spec sign(binary(), binary()) :: {:ok, binary()} | {:error, String.t()}
  def sign(_private_key, _message), do: :erlang.nif_error(:nif_not_loaded)

  @spec base(binary()) :: {:ok, binary()} | {:error, String.t()}
  def base(_message), do: :erlang.nif_error(:nif_not_loaded)

  @spec scale(binary(), binary()) :: {:ok, binary()} | {:error, String.t()}
  def scale(_point, _private_key), do: :erlang.nif_error(:nif_not_loaded)

  @spec unscale(binary(), binary()) :: {:ok, binary()} | {:error, String.t()}
  def unscale(_point, _private_key), do: :erlang.nif_error(:nif_not_loaded)

  @spec verify_transition(binary(), binary(), binary()) :: boolean()
  def verify_transition(_previous, _next, _public_key),
    do: :erlang.nif_error(:nif_not_loaded)

  @spec aggregate([binary()]) :: {:ok, binary()} | {:error, String.t()}
  def aggregate(_signatures), do: :erlang.nif_error(:nif_not_loaded)

  @spec verify([binary()], binary(), binary()) :: boolean()
  def verify(_public_keys, _message, _signature), do: :erlang.nif_error(:nif_not_loaded)
end
