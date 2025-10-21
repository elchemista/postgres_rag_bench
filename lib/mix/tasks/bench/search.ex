defmodule Mix.Tasks.Bench.Search do
  @moduledoc """
  Runs Benchee benchmarks for the different search strategies.

  Usage:

      mix bench.search --query "phoenix" --limit 5

  Options:

    * `--query`   – search text (default: "phoenix")
    * `--limit`   – number of results to fetch (default: 5)
    * `--time`    – Benchee time per scenario in seconds (default: 1.0)
    * `--warmup`  – Benchee warmup time in seconds (default: 0.5)
  """

  use Mix.Task

  @requirements ["app.start"]

  @shortdoc "Benchmark BM25 and vector searches"

  @switches [
    query: :string,
    limit: :integer,
    time: :float,
    warmup: :float
  ]

  import Ecto.Query

  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Embeddings.Bumblebee
  alias HybridSearch.Repo
  alias HybridSearch.Search

  @impl true
  def run(args) do
    {opts, _argv, _} = OptionParser.parse(args, switches: @switches)
    query = opts[:query] || "phoenix"
    limit = opts[:limit] || 5
    time = opts[:time] || 1.0
    warmup = opts[:warmup] || 0.5

    ensure_dataset!()

    dense_vector =
      case Bumblebee.embed([query]) do
        {:ok, [vector | _]} ->
          vector

        {:ok, []} ->
          Mix.shell().error("Embedding produced no vector; skipping vector benchmarks.")
          nil

        {:error, reason} ->
          Mix.shell().error("Failed to embed query: #{inspect(reason)}")
          nil
      end

    dense_embedder =
      if dense_vector do
        fn _ -> {:ok, [dense_vector]} end
      else
        nil
      end

    binary_embedder = dense_embedder

    scenarios =
      [
        {"bm25", fn -> Search.bm25(query, limit: limit) end},
        {"vector cosine",
         maybe_scenario(dense_embedder, fn ->
           Search.embedding(query, limit: limit, embedder: dense_embedder)
         end)},
        {"vector l2",
         maybe_scenario(dense_embedder, fn ->
           Search.embedding_l2(query, limit: limit, embedder: dense_embedder)
         end)},
        {"vector l1",
         maybe_scenario(dense_embedder, fn ->
           Search.embedding_l1(query, limit: limit, embedder: dense_embedder)
         end)},
        {"vector dot",
         maybe_scenario(dense_embedder, fn ->
           Search.embedding_dot(query, limit: limit, embedder: dense_embedder)
         end)},
        {"binary hamming",
         maybe_scenario(dense_embedder, fn ->
           Search.embedding_hamming(query, limit: limit, embedder: binary_embedder)
         end)},
        {"binary jaccard",
         maybe_scenario(dense_embedder, fn ->
           Search.embedding_jaccard(query, limit: limit, embedder: binary_embedder)
         end)}
      ]

    disabled =
      scenarios
      |> Enum.filter(fn {_name, fun} -> is_nil(fun) end)
      |> Enum.map(&elem(&1, 0))

    benchmarks =
      scenarios
      |> Enum.reject(fn {_name, fun} -> is_nil(fun) end)
      |> Map.new()

    if map_size(benchmarks) == 0 do
      Mix.shell().error("No benchmarks available (missing embeddings).")
    else
      if disabled != [] do
        Mix.shell().info("Skipping scenarios (missing embeddings): #{Enum.join(disabled, ", ")}")
      end

      Benchee.run(
        benchmarks,
        time: time,
        warmup: warmup,
        memory_time: 0,
        formatters: [Benchee.Formatters.Console]
      )
    end
  end

  defp maybe_scenario(nil, _fun), do: nil
  defp maybe_scenario(_embedder, fun), do: fun

  defp ensure_dataset! do
    if Repo.exists?(from(c in DatasetChunk)) do
      :ok
    else
      Mix.shell().error("No dataset chunks found. Run `mix hybrid_search.load` first.")
      Mix.raise("Cannot run benchmarks without data.")
    end
  end
end
