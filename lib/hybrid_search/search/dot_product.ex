defmodule HybridSearch.Search.DotProduct do
  @moduledoc """
  Vector similarity search that ranks results by dot product (inner product).

  Use this when your embeddings are already normalized or when larger inner
  product values should correspond to higher relevance.
  """

  import Ecto.Query, warn: false

  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Embeddings.Bumblebee
  alias HybridSearch.Repo
  alias Pgvector

  @default_limit 10

  @doc """
  Returns chunks sorted by the inner product between their embedding and the query embedding.

  Options:

    * `:limit` – number of rows to return (default #{@default_limit})
    * `:embedder` – custom embedding function with the same contract as `HybridSearch.Search.embedding/2`
  """
  @spec search(String.t(), keyword()) :: [map()]
  def search(query, opts \\ []) do
    trimmed = query |> to_string() |> String.trim()

    if trimmed == "" do
      []
    else
      embedder = Keyword.get(opts, :embedder, &default_embedder/1)
      limit = opts |> Keyword.get(:limit, @default_limit) |> normalize_limit()

      case to_vector(embedder.([trimmed])) do
        {:ok, vector} -> run_query(vector, limit)
        {:error, _} -> []
      end
    end
  end

  defp run_query(vector, limit) do
    DatasetChunk
    |> from(as: :chunk)
    |> where([chunk: c], not is_nil(c.embedding))
    |> select([chunk: c], %{
      chunk: c,
      score: fragment("-1 * (? <#> ?)", c.embedding, ^vector)
    })
    |> order_by([chunk: c], desc: fragment("-1 * (? <#> ?)", c.embedding, ^vector))
    |> limit(^limit)
    |> Repo.all()
  end

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: limit
  defp normalize_limit(_), do: @default_limit

  defp default_embedder(texts), do: Bumblebee.embed(texts)

  defp to_vector({:ok, [[_ | _] = embedding]}), do: {:ok, Pgvector.new(embedding)}
  defp to_vector({:ok, [embedding]}), do: {:ok, Pgvector.new(List.wrap(embedding))}
  defp to_vector({:ok, embedding}) when is_list(embedding), do: {:ok, Pgvector.new(embedding)}
  defp to_vector([[_ | _] = embedding]), do: {:ok, Pgvector.new(embedding)}
  defp to_vector([embedding]), do: {:ok, Pgvector.new(List.wrap(embedding))}
  defp to_vector(embedding) when is_list(embedding), do: {:ok, Pgvector.new(embedding)}
  defp to_vector(_), do: {:error, :invalid_embedding}
end
