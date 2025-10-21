defmodule HybridSearch.Search.Binary do
  @moduledoc """
  Binary vector similarity search supporting Hamming and Jaccard distances.
  """

  import Ecto.Query, warn: false

  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Embeddings.{Binary, Bumblebee}
  alias HybridSearch.Repo
  alias Pgvector

  @default_limit 10
  @binary_dimension 384

  @doc """
  Returns chunks ordered by increasing Hamming distance to the query embedding.
  """
  @spec hamming(String.t(), keyword()) :: [map()]
  def hamming(query, opts \\ []) do
    search(query, :hamming, opts)
  end

  @doc """
  Returns chunks ordered by increasing Jaccard distance to the query embedding.
  """
  @spec jaccard(String.t(), keyword()) :: [map()]
  def jaccard(query, opts \\ []) do
    search(query, :jaccard, opts)
  end

  defp search(query, operator, opts) do
    trimmed = query |> to_string() |> String.trim()

    if trimmed == "" do
      []
    else
      embedder = Keyword.get(opts, :embedder, &default_embedder/1)
      limit = opts |> Keyword.get(:limit, @default_limit) |> normalize_limit()

      with {:ok, bitstring} <- embed_to_bits(embedder, trimmed) do
        run_query(operator, bitstring, limit)
      else
        _ -> []
      end
    end
  end

  defp run_query(:hamming, bitstring, limit) do
    DatasetChunk
    |> from(as: :chunk)
    |> where([chunk: c], not is_nil(c.embedding_binary))
    |> select([chunk: c], %{
      chunk: c,
      distance: fragment("binary_hamming_distance(?, ?)", c.embedding_binary, ^bitstring)
    })
    |> order_by([chunk: c],
      asc: fragment("binary_hamming_distance(?, ?)", c.embedding_binary, ^bitstring)
    )
    |> limit(^limit)
    |> Repo.all()
  end

  defp run_query(:jaccard, bitstring, limit) do
    DatasetChunk
    |> from(as: :chunk)
    |> where([chunk: c], not is_nil(c.embedding_binary))
    |> select([chunk: c], %{
      chunk: c,
      distance: fragment("binary_jaccard_distance(?, ?)", c.embedding_binary, ^bitstring)
    })
    |> order_by([chunk: c],
      asc: fragment("binary_jaccard_distance(?, ?)", c.embedding_binary, ^bitstring)
    )
    |> limit(^limit)
    |> Repo.all()
  end

  defp embed_to_bits(embedder, query) do
    case embedder.([query]) do
      {:ok, [embedding | _]} ->
        {:ok, Binary.from_embedding(listify(embedding), size: @binary_dimension)}

      [embedding | _] ->
        {:ok, Binary.from_embedding(listify(embedding), size: @binary_dimension)}

      other ->
        {:error, other}
    end
  rescue
    error -> {:error, error}
  end

  defp listify(list) when is_list(list), do: list
  defp listify(%Pgvector{} = vector), do: Pgvector.to_list(vector)
  defp listify(_), do: nil

  defp default_embedder(texts), do: Bumblebee.embed(texts)

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: limit
  defp normalize_limit(_), do: @default_limit
end
