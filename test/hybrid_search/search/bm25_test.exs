defmodule HybridSearch.Search.Bm25Test do
  use HybridSearch.DataCase, async: true

  alias HybridSearch.Datasets
  alias HybridSearch.Search

  test "returns ranked chunks for a full-text query" do
    {:ok, chunk} =
      Datasets.upsert_chunk(%{
        source_path: "phoenix.md",
        document_title: "Phoenix",
        chunk_index: 0,
        content: "Phoenix LiveView makes building rich real-time experiences straightforward."
      })

    {:ok, _other_chunk} =
      Datasets.upsert_chunk(%{
        source_path: "ecto.md",
        document_title: "Ecto",
        chunk_index: 0,
        content: "Ecto focuses on data persistence and query composition."
      })

    results = Search.bm25("LiveView", limit: 5)

    assert [%{chunk: result_chunk, score: score, headline: headline} | _] = results
    assert result_chunk.id == chunk.id
    assert score > 0.0
    assert is_binary(headline)
  end
end
