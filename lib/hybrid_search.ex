defmodule HybridSearch do
  @moduledoc """
  High-level API for loading datasets and running hybrid search experiments.
  """

  alias HybridSearch.Datasets.Loader
  alias HybridSearch.Search

  @doc """
  Returns the default data directory where markdown documents are stored.
  """
  @spec default_data_dir() :: String.t()
  def default_data_dir do
    Application.app_dir(:hybrid_search, "priv/data")
  end

  @doc """
  Loads markdown documents into the database.
  """
  @spec load_dataset(keyword()) :: {:ok, map()} | {:error, map()}
  def load_dataset(opts \\ []) do
    {dir, opts} = Keyword.pop(opts, :dir, default_data_dir())
    Loader.load_directory(dir, opts)
  end

  @doc """
  Runs a BM25 search against the stored chunks.
  """
  @spec search_bm25(String.t(), keyword()) :: [map()]
  def search_bm25(query, opts \\ []), do: Search.bm25(query, opts)

  @doc """
  Runs a vector similarity search against stored embeddings.
  """
  @spec search_embeddings(String.t(), keyword()) :: [map()]
  def search_embeddings(query, opts \\ []), do: Search.embedding(query, opts)

  @doc """
  Runs an L2 similarity search against stored embeddings.
  """
  @spec search_embeddings_l2(String.t(), keyword()) :: [map()]
  def search_embeddings_l2(query, opts \\ []), do: Search.embedding_l2(query, opts)

  @doc """
  Runs an L1 similarity search against stored embeddings.
  """
  @spec search_embeddings_l1(String.t(), keyword()) :: [map()]
  def search_embeddings_l1(query, opts \\ []), do: Search.embedding_l1(query, opts)

  @doc """
  Runs an inner-product-based similarity search against the stored embeddings.
  """
  @spec search_embeddings_dot(String.t(), keyword()) :: [map()]
  def search_embeddings_dot(query, opts \\ []), do: Search.embedding_dot(query, opts)

  @doc """
  Runs a Hamming-distance search over the stored binary embeddings.
  """
  @spec search_embeddings_hamming(String.t(), keyword()) :: [map()]
  def search_embeddings_hamming(query, opts \\ []), do: Search.embedding_hamming(query, opts)

  @doc """
  Runs a Jaccard-distance search over the stored binary embeddings.
  """
  @spec search_embeddings_jaccard(String.t(), keyword()) :: [map()]
  def search_embeddings_jaccard(query, opts \\ []), do: Search.embedding_jaccard(query, opts)
end
