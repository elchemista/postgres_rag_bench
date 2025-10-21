defmodule HybridSearch.Embeddings.Binary do
  @moduledoc """
  Helpers for converting dense embeddings into binary bitstrings (as "0"/"1" strings).
  """

  alias Pgvector

  @default_dimension 384

  @doc """
  Converts a single embedding into a string of 0s and 1s using the provided threshold.
  """
  @spec from_embedding(list(number()) | Pgvector.t() | nil, keyword()) :: String.t()
  def from_embedding(nil, opts) do
    dimension = Keyword.get(opts, :size, @default_dimension)
    zero_bits(dimension)
  end

  def from_embedding(%Pgvector{} = vector, opts) do
    vector
    |> Pgvector.to_list()
    |> from_embedding(opts)
  end

  def from_embedding(embedding, opts) when is_list(embedding) do
    threshold = Keyword.get(opts, :threshold, 0.0)
    size = Keyword.get(opts, :size, length(embedding))

    embedding
    |> Enum.map(fn value -> if value > threshold, do: "1", else: "0" end)
    |> Enum.join()
    |> pad_to_length(size)
  end

  def from_embedding(_unknown, opts), do: from_embedding(nil, opts)

  @doc """
  Converts a list of embeddings into bitstrings, normalizing them to the same length.
  """
  @spec from_embeddings([list(number()) | Pgvector.t() | nil], keyword()) :: [String.t()]
  def from_embeddings(embeddings, opts \\ []) do
    dimension = inference_dimension(embeddings) || Keyword.get(opts, :size, @default_dimension)
    threshold = Keyword.get(opts, :threshold, 0.0)

    embeddings
    |> Enum.map(&from_embedding(&1, size: dimension, threshold: threshold))
  end

  @spec zero_bits(non_neg_integer()) :: String.t()
  def zero_bits(length) when length >= 0 do
    String.duplicate("0", length)
  end

  defp inference_dimension([]), do: nil
  defp inference_dimension([nil | rest]), do: inference_dimension(rest)

  defp inference_dimension([%Pgvector{} = vector | _]) do
    vector
    |> Pgvector.to_list()
    |> length()
  end

  defp inference_dimension([[value | _] = embedding | _]) when is_number(value) do
    length(embedding)
  end

  defp inference_dimension([_ | rest]), do: inference_dimension(rest)

  defp pad_to_length(bitstring, desired) do
    case String.length(bitstring) do
      ^desired -> bitstring
      len when len > desired -> String.slice(bitstring, 0, desired)
      len -> bitstring <> zero_bits(desired - len)
    end
  end
end
