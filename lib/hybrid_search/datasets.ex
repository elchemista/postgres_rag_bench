defmodule HybridSearch.Datasets do
  @moduledoc """
  Public interface for working with dataset chunks stored in PostgreSQL.
  """

  import Ecto.Query, warn: false

  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Repo

  @type chunk_attrs :: %{
          required(:source_path) => String.t(),
          required(:document_title) => String.t(),
          required(:chunk_index) => non_neg_integer(),
          required(:content) => String.t(),
          optional(:embedding) => Pgvector.Ecto.Vector.t(),
          optional(:embedding_binary) => binary()
        }

  @doc """
  Inserts or updates a dataset chunk, ensuring idempotency per source and chunk index.
  """
  @spec upsert_chunk(chunk_attrs()) :: {:ok, DatasetChunk.t()} | {:error, Ecto.Changeset.t()}
  def upsert_chunk(attrs) do
    changeset = DatasetChunk.changeset(%DatasetChunk{}, attrs)

    Repo.insert(changeset,
      on_conflict:
        {:replace, [:document_title, :content, :embedding, :embedding_binary, :updated_at]},
      conflict_target: [:source_path, :chunk_index]
    )
  end

  @doc """
  Fetches dataset chunks with optional limit. Defaults to 50 rows to keep responses small.
  """
  @spec list_chunks(keyword()) :: [DatasetChunk.t()]
  def list_chunks(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    DatasetChunk
    |> order_by([dc], asc: dc.source_path, asc: dc.chunk_index)
    |> limit(^limit)
    |> Repo.all()
  end
end
