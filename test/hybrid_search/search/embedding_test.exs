defmodule HybridSearch.Search.EmbeddingTest do
  use HybridSearch.DataCase, async: false

  alias HybridSearch.Datasets
  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Repo
  alias HybridSearch.Search
  alias Pgvector

  @dim 384

  setup do
    Repo.delete_all(DatasetChunk)
    :ok
  end

  describe "vector searches" do
    test "cosine distance returns closest chunk" do
      {:ok, _chunk1} =
        Datasets.upsert_chunk(%{
          source_path: "doc1.md",
          document_title: "Doc1",
          chunk_index: 0,
          content: "First document",
          embedding: Pgvector.new(unit_vector(0)),
          embedding_binary: unit_bits(0)
        })

      {:ok, chunk2} =
        Datasets.upsert_chunk(%{
          source_path: "doc2.md",
          document_title: "Doc2",
          chunk_index: 0,
          content: "Second document",
          embedding: Pgvector.new(unit_vector(1)),
          embedding_binary: unit_bits(1)
        })

      embedder = fn _texts -> {:ok, [unit_vector(1)]} end

      results = Search.embedding("query", embedder: embedder, limit: 2)

      assert [%{chunk: result_chunk, distance: distance} | _] = results
      assert result_chunk.id == chunk2.id
      assert distance == 0.0
    end

    test "inner product returns highest scoring chunk" do
      {:ok, chunk_a} =
        Datasets.upsert_chunk(%{
          source_path: "dot_a.md",
          document_title: "Dot A",
          chunk_index: 0,
          content: "Dot product A",
          embedding: Pgvector.new(unit_vector(2)),
          embedding_binary: unit_bits(2)
        })

      {:ok, _chunk_b} =
        Datasets.upsert_chunk(%{
          source_path: "dot_b.md",
          document_title: "Dot B",
          chunk_index: 0,
          content: "Dot product B",
          embedding: Pgvector.new(unit_vector(3)),
          embedding_binary: unit_bits(3)
        })

      embedder = fn _texts -> {:ok, [unit_vector(2)]} end

      results = Search.embedding_dot("dot query", embedder: embedder, limit: 2)

      assert [%{chunk: result_chunk, score: score} | _] = results
      assert result_chunk.id == chunk_a.id
      assert score == 1.0
    end

    test "l2 distance returns closest chunk" do
      {:ok, _chunk1} =
        Datasets.upsert_chunk(%{
          source_path: "doc3.md",
          document_title: "Doc3",
          chunk_index: 0,
          content: "Third document",
          embedding: Pgvector.new(unit_vector(10)),
          embedding_binary: unit_bits(10)
        })

      {:ok, chunk2} =
        Datasets.upsert_chunk(%{
          source_path: "doc4.md",
          document_title: "Doc4",
          chunk_index: 0,
          content: "Fourth document",
          embedding: Pgvector.new(unit_vector(11)),
          embedding_binary: unit_bits(11)
        })

      embedder = fn _texts -> {:ok, [unit_vector(11)]} end

      results = Search.embedding_l2("query", embedder: embedder, limit: 2)

      assert [%{chunk: result_chunk, distance: distance} | _] = results
      assert result_chunk.id == chunk2.id
      assert distance == 0.0
    end

    test "l1 distance returns closest chunk" do
      {:ok, _chunk1} =
        Datasets.upsert_chunk(%{
          source_path: "doc5.md",
          document_title: "Doc5",
          chunk_index: 0,
          content: "Fifth document",
          embedding: Pgvector.new(unit_vector(12)),
          embedding_binary: unit_bits(12)
        })

      {:ok, chunk2} =
        Datasets.upsert_chunk(%{
          source_path: "doc6.md",
          document_title: "Doc6",
          chunk_index: 0,
          content: "Sixth document",
          embedding: Pgvector.new(unit_vector(13)),
          embedding_binary: unit_bits(13)
        })

      embedder = fn _texts -> {:ok, [unit_vector(13)]} end

      results = Search.embedding_l1("query", embedder: embedder, limit: 2)

      assert [%{chunk: result_chunk, distance: distance} | _] = results
      assert result_chunk.id == chunk2.id
      assert distance == 0.0
    end
  end

  describe "binary searches" do
    test "hamming distance returns closest chunk" do
      {:ok, chunk_a} =
        Datasets.upsert_chunk(%{
          source_path: "binary_a.md",
          document_title: "Binary A",
          chunk_index: 0,
          content: "Binary document A",
          embedding: nil,
          embedding_binary: unit_bits(20)
        })

      {:ok, _chunk_b} =
        Datasets.upsert_chunk(%{
          source_path: "binary_b.md",
          document_title: "Binary B",
          chunk_index: 0,
          content: "Binary document B",
          embedding: nil,
          embedding_binary: unit_bits(21)
        })

      embedder = fn _texts -> {:ok, [unit_vector(20)]} end

      results = Search.embedding_hamming("binary query", embedder: embedder, limit: 2)

      assert [%{chunk: result_chunk, distance: distance} | _] = results
      assert result_chunk.id == chunk_a.id
      assert distance == 0
    end

    test "jaccard distance returns closest chunk" do
      {:ok, chunk_a} =
        Datasets.upsert_chunk(%{
          source_path: "binary_c.md",
          document_title: "Binary C",
          chunk_index: 0,
          content: "Binary document C",
          embedding: nil,
          embedding_binary: unit_bits(22)
        })

      {:ok, _chunk_b} =
        Datasets.upsert_chunk(%{
          source_path: "binary_d.md",
          document_title: "Binary D",
          chunk_index: 0,
          content: "Binary document D",
          embedding: nil,
          embedding_binary: unit_bits(23)
        })

      embedder = fn _texts -> {:ok, [unit_vector(22)]} end

      results = Search.embedding_jaccard("binary query", embedder: embedder, limit: 2)

      assert [%{chunk: result_chunk, distance: distance} | _] = results
      assert result_chunk.id == chunk_a.id
      assert distance == 0
    end
  end

  defp unit_vector(position) do
    for index <- 0..(@dim - 1) do
      if index == position, do: 1.0, else: 0.0
    end
  end

  defp unit_bits(position) do
    for index <- 0..(@dim - 1), into: "" do
      if index == position, do: "1", else: "0"
    end
  end
end
