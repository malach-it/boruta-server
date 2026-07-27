defmodule BorutaAuth.BlsKeyPair do
  @moduledoc """
  BLS12-381 G1 keys used by the degree-three-phi data-token protocol.

  Public keys use the compressed 48-byte form and DIDs use the BLS12-381 G1
  `did:key` multicodec (`0xea01`). Phi data tokens bind a user's public key to
  a domain-separated commitment of a metadata attribute name and canonical
  JSON value.
  """

  import Bitwise

  @field_modulus String.to_integer(
                   "1A0111EA397FE69A4B1BA7B6434BACD7" <>
                     "64774B84F38512BF6730D2A0F6B0F624" <>
                     "1EABFFFEB153FFFFB9FEFFFFFFFFAAAB",
                   16
                 )
  @group_order String.to_integer(
                 "73EDA753299D7D483339D80809A1D805" <>
                   "53BDA402FFFE5BFEFFFFFFFF00000001",
                 16
               )
  @generator {
    String.to_integer(
      "17F1D3A73197D7942695638C4FA9AC0F" <>
        "C3688C4F9774B905A14E3A3F171BAC5" <>
        "86C55E83FF97A1AEFFB3AF00ADB22C6BB",
      16
    ),
    String.to_integer(
      "08B3F481E3AAA0F1A09E30ED741D8AE4" <>
        "FCF5E095D5D00AF600DB18CB2C04B3E" <>
        "DD03CC744A2888AE40CAA232946C5E7E1",
      16
    ),
    1
  }
  @base58_alphabet ~c"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

  @type key_pair :: %{
          private_key: binary(),
          public_key: binary(),
          did_key: String.t()
        }

  @spec generate() :: key_pair()
  def generate do
    private_key = random_scalar()
    public_key = private_key |> decode_integer() |> public_key_for_scalar()

    %{
      private_key: private_key,
      public_key: public_key,
      did_key: did_key(public_key)
    }
  end

  @phi_data_token_domain "BORUTA_PHI_DATA_TOKEN_V1"

  @spec phi_data_token(binary(), String.t(), term()) ::
          {:ok, String.t()} | {:error, String.t()}
  def phi_data_token(public_key, attribute_name, value)
      when is_binary(public_key) and is_binary(attribute_name) do
    with {:ok, point} <- decompress(public_key),
         {:ok, commitment} <- commitment_scalar(attribute_name, value) do
      {:ok, point |> multiply(commitment) |> compress() |> did_key()}
    end
  end

  def phi_data_token(_public_key, _attribute_name, _value),
    do: {:error, "attribute name must be a string"}

  @spec verify_phi_data_token(binary(), String.t(), term(), String.t()) :: boolean()
  def verify_phi_data_token(public_key, attribute_name, value, token)
      when is_binary(token) do
    case phi_data_token(public_key, attribute_name, value) do
      {:ok, expected_token} -> expected_token == token
      {:error, _reason} -> false
    end
  end

  def verify_phi_data_token(_public_key, _attribute_name, _value, _token), do: false

  @spec did_key(binary()) :: String.t()
  def did_key(<<_::binary-size(48)>> = public_key) do
    "did:key:z" <> base58_encode(<<0xEA, 0x01, public_key::binary>>)
  end

  defp random_scalar do
    scalar =
      32
      |> :crypto.strong_rand_bytes()
      |> decode_integer()
      |> rem(@group_order - 1)
      |> Kernel.+(1)

    <<scalar::unsigned-big-integer-size(256)>>
  end

  defp public_key_for_scalar(scalar), do: @generator |> multiply(scalar) |> compress()

  defp commitment_scalar(attribute_name, value) do
    with {:ok, canonical_value} <- canonical_json(value) do
      commitment =
        :crypto.hash(
          :sha256,
          [
            @phi_data_token_domain,
            <<byte_size(attribute_name)::unsigned-big-integer-size(64)>>,
            attribute_name,
            <<byte_size(canonical_value)::unsigned-big-integer-size(64)>>,
            canonical_value
          ]
        )
        |> decode_integer()
        |> rem(@group_order - 1)
        |> Kernel.+(1)

      {:ok, commitment}
    end
  end

  defp canonical_json(value) when is_map(value) do
    value
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.reduce_while({:ok, []}, fn {key, value}, {:ok, entries} ->
      case canonical_json(value) do
        {:ok, encoded_value} ->
          entry = [Jason.encode!(key), ?:, encoded_value]
          {:cont, {:ok, [entry | entries]}}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} ->
        {:ok, IO.iodata_to_binary([?{, Enum.intersperse(Enum.reverse(entries), ?,), ?}])}

      error ->
        error
    end
  end

  defp canonical_json(value) when is_list(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, entries} ->
      case canonical_json(value) do
        {:ok, encoded_value} -> {:cont, {:ok, [encoded_value | entries]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} ->
        {:ok, IO.iodata_to_binary([?[, Enum.intersperse(Enum.reverse(entries), ?,), ?]])}

      error ->
        error
    end
  end

  defp canonical_json(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value) do
    {:ok, Jason.encode!(value)}
  end

  defp canonical_json(_value), do: {:error, "attribute value must be valid JSON"}

  defp multiply(point, scalar), do: multiply(point, scalar, :infinity)
  defp multiply(_point, 0, result), do: result

  defp multiply(point, scalar, result) do
    result = if band(scalar, 1) == 1, do: add(result, point), else: result
    multiply(double(point), bsr(scalar, 1), result)
  end

  defp add(:infinity, point), do: point
  defp add(point, :infinity), do: point

  defp add({x1, y1, z1}, {x2, y2, z2}) do
    z1z1 = mod(z1 * z1)
    z2z2 = mod(z2 * z2)
    u1 = mod(x1 * z2z2)
    u2 = mod(x2 * z1z1)
    s1 = mod(y1 * z2 * z2z2)
    s2 = mod(y2 * z1 * z1z1)

    cond do
      u1 == u2 and s1 != s2 ->
        :infinity

      u1 == u2 ->
        double({x1, y1, z1})

      true ->
        h = mod(u2 - u1)
        i = mod(4 * h * h)
        j = mod(h * i)
        r = mod(2 * (s2 - s1))
        v = mod(u1 * i)
        x3 = mod(r * r - j - 2 * v)
        y3 = mod(r * (v - x3) - 2 * s1 * j)
        z3 = mod(((z1 + z2) * (z1 + z2) - z1z1 - z2z2) * h)
        {x3, y3, z3}
    end
  end

  defp double(:infinity), do: :infinity
  defp double({_x, 0, _z}), do: :infinity

  defp double({x, y, z}) do
    a = mod(x * x)
    b = mod(y * y)
    c = mod(b * b)
    d = mod(2 * ((x + b) * (x + b) - a - c))
    e = mod(3 * a)
    f = mod(e * e)
    x3 = mod(f - 2 * d)
    y3 = mod(e * (d - x3) - 8 * c)
    z3 = mod(2 * y * z)
    {x3, y3, z3}
  end

  defp compress(point) do
    {x, y} = affine(point)
    sort_flag = if y > @field_modulus - y, do: 0x20, else: 0
    <<first, rest::binary>> = <<x::unsigned-big-integer-size(384)>>
    <<bor(first, bor(0x80, sort_flag)), rest::binary>>
  end

  defp decompress(<<first, rest::binary-size(47)>>) do
    compressed? = band(first, 0x80) != 0
    infinity? = band(first, 0x40) != 0
    sort? = band(first, 0x20) != 0
    x = decode_integer(<<band(first, 0x1F), rest::binary>>)

    with true <- compressed? and not infinity? and x < @field_modulus,
         y_squared = mod(x * x * x + 4),
         y = pow(y_squared, div(@field_modulus + 1, 4)),
         true <- mod(y * y) == y_squared do
      y = if y > @field_modulus - y == sort?, do: y, else: @field_modulus - y
      {:ok, {x, y, 1}}
    else
      _ -> {:error, "invalid BLS12-381 G1 public key"}
    end
  end

  defp decompress(_public_key), do: {:error, "invalid BLS12-381 G1 public key"}

  defp affine(:infinity), do: raise(ArgumentError, "point at infinity has no affine encoding")

  defp affine({x, y, z}) do
    inverse = pow(z, @field_modulus - 2)
    inverse_squared = mod(inverse * inverse)
    {mod(x * inverse_squared), mod(y * inverse_squared * inverse)}
  end

  defp pow(_base, 0), do: 1
  defp pow(base, exponent), do: pow(mod(base), exponent, 1)
  defp pow(_base, 0, result), do: result

  defp pow(base, exponent, result) do
    result = if band(exponent, 1) == 1, do: mod(result * base), else: result
    pow(mod(base * base), bsr(exponent, 1), result)
  end

  defp mod(integer) do
    case rem(integer, @field_modulus) do
      result when result < 0 -> result + @field_modulus
      result -> result
    end
  end

  defp decode_integer(binary), do: :binary.decode_unsigned(binary)

  defp base58_encode(bytes) do
    leading_zeroes = bytes |> :binary.bin_to_list() |> Enum.take_while(&(&1 == 0)) |> length()
    encoded = encode_base58_integer(decode_integer(bytes), [])
    List.to_string(List.duplicate(?1, leading_zeroes) ++ encoded)
  end

  defp encode_base58_integer(0, chars), do: chars

  defp encode_base58_integer(integer, chars) do
    encode_base58_integer(
      div(integer, 58),
      [Enum.at(@base58_alphabet, rem(integer, 58)) | chars]
    )
  end
end
