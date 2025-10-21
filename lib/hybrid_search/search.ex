defmodule HybridSearch.Search do
  @moduledoc """
  Entry points for search strategies.
  """

  alias HybridSearch.Search.{Binary, Bm25, DotProduct, Embedding, L1, L2}

  @doc """
  Executes a BM25 full-text search.

  The result is a list of maps with `:chunk`, `:score`, and `:headline` keys.
  """
  @spec bm25(String.t(), keyword()) :: [map()]
  def bm25(query, opts \\ []), do: Bm25.search(query, opts)

  @doc """
  Executes an embedding-based similarity search.

  The result includes the dataset chunk and the cosine distance from the query vector.
  """
  @spec embedding(String.t(), keyword()) :: [map()]
  def embedding(query, opts \\ []), do: Embedding.search(query, opts)

  @doc """
  Executes an L2 (Euclidean) similarity search.
  """
  @spec embedding_l2(String.t(), keyword()) :: [map()]
  def embedding_l2(query, opts \\ []), do: L2.search(query, opts)

  @doc """
  Executes an L1 (Manhattan) similarity search.
  """
  @spec embedding_l1(String.t(), keyword()) :: [map()]
  def embedding_l1(query, opts \\ []), do: L1.search(query, opts)

  @doc """
  Executes an inner-product similarity search.

  Useful when embeddings are normalized and dot product corresponds to similarity.
  """
  @spec embedding_dot(String.t(), keyword()) :: [map()]
  def embedding_dot(query, opts \\ []), do: DotProduct.search(query, opts)

  @doc """
  Executes a Hamming-distance similarity search over binary embeddings.
  """
  @spec embedding_hamming(String.t(), keyword()) :: [map()]
  def embedding_hamming(query, opts \\ []), do: Binary.hamming(query, opts)

  @doc """
  Executes a Jaccard-distance similarity search over binary embeddings.
  """
  @spec embedding_jaccard(String.t(), keyword()) :: [map()]
  def embedding_jaccard(query, opts \\ []), do: Binary.jaccard(query, opts)
end
