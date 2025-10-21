defmodule HybridSearch.Datasets.LoaderChunkTest do
  use ExUnit.Case, async: true

  alias HybridSearch.Datasets.Loader

  test "splits markdown content into chunks respecting limits" do
    content = """
    # Title

    Elixir makes concurrent programming approachable.

    Phoenix LiveView keeps stateful connections without JavaScript.

    Ecto offers a composable query DSL.
    """

    chunks = Loader.chunk_markdown(content, 80)

    assert length(chunks) >= 1
    assert Enum.all?(chunks, &is_binary/1)
    assert Enum.all?(chunks, &(String.length(&1) <= 120))
  end
end
