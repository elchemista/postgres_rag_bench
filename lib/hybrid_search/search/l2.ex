defmodule HybridSearch.Search.L2 do
  @moduledoc """
  Vector similarity search using L2 (Euclidean) distance.
  """

  import Ecto.Query, warn: false

  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Embeddings.Bumblebee
  alias HybridSearch.Repo
  alias Pgvector

  @default_limit 10

  @doc """
  Returns chunks ordered by increasing L2 distance to the query embedding.
  """
  @spec search(String.t(), keyword()) :: [map()]
  def search(query, opts \\ []) do
    trimmed = query |> to_string() |> String.trim()

    if trimmed == "" do
      []
    else
      embedder = Keyword.get(opts, :embedder, &default_embedder/1)
      limit = opts |> Keyword.get(:limit, @default_limit) |> normalize_limit()

      with {:ok, vector} <- embed_to_pgvector(embedder, trimmed) do
        run_query(vector, limit)
      else
        _ -> []
      end
    end
  end

  defp run_query(vector, limit) do
    DatasetChunk
    |> from(as: :chunk)
    |> where([chunk: c], not is_nil(c.embedding))
    |> select([chunk: c], %{
      chunk: c,
      distance: fragment("? <-> ?", c.embedding, ^vector)
    })
    |> order_by([chunk: c], asc: fragment("? <-> ?", c.embedding, ^vector))
    |> limit(^limit)
    |> Repo.all()
  end

  defp embed_to_pgvector(embedder, query) do
    case embedder.([query]) do
      {:ok, [embedding | _]} -> {:ok, Pgvector.new(listify(embedding))}
      [embedding | _] -> {:ok, Pgvector.new(listify(embedding))}
      other -> {:error, other}
    end
  rescue
    error -> {:error, error}
  end

  defp listify(%Pgvector{} = vector), do: Pgvector.to_list(vector)
  defp listify(list) when is_list(list), do: list

  defp default_embedder(texts), do: Bumblebee.embed(texts)

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: limit
  defp normalize_limit(_), do: @default_limit
end
