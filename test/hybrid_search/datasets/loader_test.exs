defmodule HybridSearch.Datasets.LoaderTest do
  use HybridSearch.DataCase, async: true

  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Datasets.Loader
  alias HybridSearch.Repo

  test "loads markdown file and persists chunks" do
    Repo.delete_all(DatasetChunk)

    tmp_dir = Path.join(System.tmp_dir!(), "hybrid_search_loader_test_#{System.unique_integer()}")
    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    file_path = Path.join(tmp_dir, "sample.md")

    File.write!(file_path, """
    # Sample Document

    Phoenix and LiveView work great together.

    PostgreSQL full-text search ships with BM25 ranking functionality.
    """)

    assert {:ok, chunk_count} =
             Loader.load_file(file_path,
               base_dir: tmp_dir,
               chunk_size: 120
             )

    assert chunk_count > 0

    stored =
      DatasetChunk
      |> Repo.all()

    assert Enum.any?(stored, fn chunk ->
             chunk.source_path == "sample.md" and chunk.document_title == "Sample Document"
           end)

    assert stored |> Enum.map(& &1.chunk_index) |> Enum.uniq() ==
             Enum.map(stored, & &1.chunk_index)
  end
end
