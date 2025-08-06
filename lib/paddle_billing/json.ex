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
      {:ok, :json.decode(binary)}
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
end