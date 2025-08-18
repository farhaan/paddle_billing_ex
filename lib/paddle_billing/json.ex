defmodule PaddleBilling.JSON do
  @moduledoc """
  JSON encoding/decoding with native :json fallback to Jason.
  
  Prefers native :json (available in OTP 27+) for better performance,
  gracefully falls back to Jason on older versions.
  """

  @doc """
  Decodes a JSON binary string.
  
  Returns {:ok, decoded} or {:error, reason}.
  """
  @spec decode(binary()) :: {:ok, term()} | {:error, term()}
  def decode(binary) when is_binary(binary) do
    try do
      # Try native :json first (available in OTP 27+)
      result = :json.decode(binary)
      # Convert :null to nil for consistency with Jason
      {:ok, normalize_nulls(result)}
    rescue
      UndefinedFunctionError ->
        # Fallback to Jason
        Jason.decode(binary)
    catch
      :error, reason ->
        {:error, reason}
    end
  end

  @doc """
  Encodes a term to JSON binary string.
  
  Returns {:ok, encoded} or {:error, reason}.
  """
  @spec encode(term()) :: {:ok, binary()} | {:error, term()}
  def encode(term) do
    try do
      # Try native :json first (available in OTP 27+)
      # Convert iodata to binary for consistency
      {:ok, IO.iodata_to_binary(:json.encode(term))}
    rescue
      UndefinedFunctionError ->
        # Fallback to Jason
        Jason.encode(term)
    catch
      :error, reason ->
        {:error, reason}
    end
  end

  @doc """
  Decodes a JSON binary string, raising on error.
  
  Returns decoded term or raises.
  """
  @spec decode!(binary()) :: term()
  def decode!(binary) when is_binary(binary) do
    case decode(binary) do
      {:ok, decoded} -> decoded
      {:error, reason} -> raise Jason.DecodeError, data: binary, position: 0, token: reason
    end
  end

  @doc """
  Encodes a term to JSON binary string, raising on error.
  
  Returns encoded binary or raises.
  """
  @spec encode!(term()) :: binary()
  def encode!(term) do
    case encode(term) do
      {:ok, encoded} -> encoded
      {:error, reason} -> raise Jason.EncodeError, value: term, message: to_string(reason)
    end
  end

  # Recursively convert :null atoms to nil for compatibility with Jason
  @spec normalize_nulls(term()) :: term()
  defp normalize_nulls(:null), do: nil
  defp normalize_nulls(value) when is_map(value) do
    Enum.into(value, %{}, fn {k, v} -> {k, normalize_nulls(v)} end)
  end
  defp normalize_nulls(value) when is_list(value) do
    Enum.map(value, &normalize_nulls/1)
  end
  defp normalize_nulls(value), do: value
end