defmodule HybridSearch.Datasets.Loader do
  @moduledoc """
  Minimal data loader that reads Markdown files, splits them into chunks, and stores them.

  Each chunk becomes a `HybridSearch.Datasets.DatasetChunk` row. By default the loader
  calls `HybridSearch.Embeddings.Bumblebee` to produce dense vectors using the
  `thenlper/gte-small` model, but you can pass your own embedding and binary encoder
  callbacks through the options.
  """

  alias HybridSearch.Datasets
  alias HybridSearch.Datasets.DatasetChunk
  alias HybridSearch.Embeddings.{Binary, Bumblebee}
  alias Pgvector

  require Logger

  @type embedder_fun :: (list(String.t()) -> list(list(number()) | nil))
  @type binary_fun ::
          (list(list(number()) | nil) -> list(String.t()))
          | (list(list(number()) | nil), list(String.t()) -> list(String.t()))

  @default_glob "*.md"
  @default_chunk_size 800

  @default_binary_dim 384

  @doc """
  Loads every Markdown file that matches `glob` inside `directory`.

  ## Options

    * `:glob` – file glob relative to `directory` (defaults to `"#{@default_glob}"`)
    * `:chunk_size` – maximum characters in each chunk (defaults to #{@default_chunk_size})
    * `:embedder` – function that receives the list of chunk strings and returns dense embeddings
    * `:binary_encoder` – function that receives chunk strings and returns binary vectors

  Returns `{:ok, %{files: ..., chunks: ...}}` when everything succeeded or
  `{:error, %{files: ..., chunks: ..., errors: [...]}}` when one or more files failed.
  """
  @spec load_directory(Path.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def load_directory(directory, opts \\ []) do
    directory = Path.expand(directory)
    glob = Keyword.get(opts, :glob, @default_glob)
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    embedder = Keyword.get(opts, :embedder, &default_embedder/1)
    binary_encoder = Keyword.get(opts, :binary_encoder, &default_binary_encoder/2)

    directory
    |> Path.join(glob)
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.reduce({0, 0, []}, fn path, {files, chunks, errors} ->
      case load_file(path,
             base_dir: directory,
             chunk_size: chunk_size,
             embedder: embedder,
             binary_encoder: binary_encoder
           ) do
        {:ok, count} -> {files + 1, chunks + count, errors}
        {:error, reason} -> {files + 1, chunks, [{path, reason} | errors]}
      end
    end)
    |> finalize_result()
  end

  @doc """
  Loads a single Markdown file into the database.
  """
  @spec load_file(Path.t(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def load_file(path, opts \\ []) do
    with {:ok, content} <- File.read(path) do
      directory = Keyword.get(opts, :base_dir, Path.dirname(path))
      chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
      embedder = Keyword.get(opts, :embedder, &default_embedder/1)
      binary_encoder = Keyword.get(opts, :binary_encoder, &default_binary_encoder/2)

      chunks = chunk_markdown(content, chunk_size)
      dense = run_embedder(embedder, chunks)
      binary = run_binary_encoder(binary_encoder, chunks, dense)

      attrs =
        chunks
        |> Enum.with_index()
        |> Enum.map(fn {chunk, index} ->
          %{
            source_path: relative_path(path, directory),
            document_title: guess_title(content, path),
            chunk_index: index,
            content: chunk,
            embedding: dense |> Enum.at(index) |> to_pgvector(),
            embedding_binary: Enum.at(binary, index)
          }
        end)

      upsert_all(attrs)
    end
  end

  @doc """
  Very small paragraph-based chunker.

  Splits the document on blank lines and assembles paragraphs until
  the text would exceed `chunk_size`. This keeps the code readable and
  predictable for small datasets.
  """
  @spec chunk_markdown(String.t(), pos_integer()) :: [String.t()]
  def chunk_markdown(content, chunk_size) when chunk_size > 0 do
    content
    |> String.split(~r/\R{2,}/u, trim: true)
    |> Enum.reduce([], fn paragraph, acc ->
      paragraph = String.trim(paragraph)

      case acc do
        [] ->
          [paragraph]

        [current | rest] ->
          combined = current <> "\n\n" <> paragraph

          if String.length(combined) <= chunk_size do
            [combined | rest]
          else
            [paragraph | acc]
          end
      end
    end)
    |> Enum.reverse()
  end

  # -- Helpers -----------------------------------------------------------------

  defp run_embedder(fun, chunks) do
    count = length(chunks)

    case safe_call(fun, chunks) do
      {:ok, vectors} when is_list(vectors) ->
        normalize_list(vectors, count)

      {:ok, _unexpected} ->
        log_embedder_warning(:invalid_return)
        empty_list(count)

      {:error, reason} ->
        log_embedder_warning(reason)
        empty_list(count)
    end
  end

  defp run_binary_encoder(fun, chunks, dense_embeddings) do
    count = length(chunks)

    dimension = infer_dimension(dense_embeddings) || @default_binary_dim

    case safe_binary_call(fun, dense_embeddings, chunks) do
      {:ok, binaries} when is_list(binaries) ->
        binaries
        |> Enum.map(&ensure_bitstring(&1, dimension))
        |> normalize_list(count)

      {:ok, _unexpected} ->
        log_encoder_warning(:invalid_return)
        default_binary_list(count, dimension)

      {:error, reason} ->
        log_encoder_warning(reason)
        default_binary_list(count, dimension)
    end
  end

  defp safe_call(fun, chunks) do
    try do
      case fun.(chunks) do
        {:ok, result} -> {:ok, result}
        result -> {:ok, result}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp safe_binary_call(fun, embeddings, chunks) do
    try do
      arity =
        case :erlang.fun_info(fun, :arity) do
          {:arity, value} -> value
          _ -> 2
        end

      result =
        case arity do
          2 -> fun.(embeddings, chunks)
          1 -> fun.(embeddings)
          0 -> fun.()
          _ -> raise ArgumentError, "binary encoder must accept 1 or 2 arguments"
        end

      case result do
        {:ok, value} -> {:ok, value}
        value -> {:ok, value}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp normalize_list(list, expected) when length(list) == expected, do: list
  defp normalize_list(list, expected) when length(list) == 0, do: empty_list(expected)

  defp normalize_list(list, expected) when length(list) < expected,
    do: list ++ empty_list(expected - length(list))

  defp normalize_list(list, expected), do: list |> Enum.take(expected)

  defp finalize_result({files, chunks, []}), do: {:ok, %{files: files, chunks: chunks}}

  defp finalize_result({files, chunks, errors}),
    do: {:error, %{files: files, chunks: chunks, errors: Enum.reverse(errors)}}

  defp upsert_all(attrs) do
    attrs
    |> Enum.reduce_while(0, fn params, acc ->
      case Datasets.upsert_chunk(params) do
        {:ok, %DatasetChunk{}} -> {:cont, acc + 1}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      count -> {:ok, count}
    end
  end

  defp relative_path(path, directory) do
    try do
      Path.relative_to(path, directory)
    rescue
      ArgumentError -> Path.relative_to_cwd(path)
    end
  end

  defp guess_title(content, path) do
    content
    |> String.split("\n")
    |> Enum.find_value(fn line ->
      line = String.trim_leading(line)
      if String.starts_with?(line, "#"), do: String.trim_leading(line, "# ") |> String.trim()
    end)
    |> case do
      nil ->
        path
        |> Path.basename(".md")
        |> String.replace(~r/[_-]/, " ")
        |> titleize()

      heading ->
        heading
    end
  end

  defp titleize(text) do
    text
    |> String.split(~r/\s+/)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp to_pgvector(nil), do: nil
  defp to_pgvector(%Pgvector{} = vector), do: vector
  defp to_pgvector(list) when is_list(list), do: Pgvector.new(list)
  defp to_pgvector(_unknown), do: nil

  # Default callbacks keep the loader usable without any external model.
  defp default_embedder(chunks) do
    case Bumblebee.embed(chunks) do
      {:ok, embeddings} ->
        embeddings

      {:error, reason} ->
        log_embedder_warning(reason)
        empty_list(length(chunks))
    end
  end

  defp default_binary_encoder(embeddings, _chunks) do
    Binary.from_embeddings(embeddings)
  end

  defp empty_list(count), do: for(_ <- 1..count, do: nil)

  defp default_binary_list(count, dimension),
    do: for(_ <- 1..count, do: Binary.zero_bits(dimension))

  defp ensure_bitstring(nil, dimension), do: Binary.zero_bits(dimension)

  defp ensure_bitstring(bitstring, dimension) when is_binary(bitstring) do
    cond do
      String.length(bitstring) == dimension -> bitstring
      String.length(bitstring) > dimension -> String.slice(bitstring, 0, dimension)
      true -> bitstring <> Binary.zero_bits(dimension - String.length(bitstring))
    end
  end

  defp ensure_bitstring(other, dimension) do
    Logger.warning("Unexpected binary embedding format: #{inspect(other)}")
    Binary.zero_bits(dimension)
  end

  defp infer_dimension([]), do: nil
  defp infer_dimension([nil | rest]), do: infer_dimension(rest)
  defp infer_dimension([%Pgvector{} = vector | _]), do: vector |> Pgvector.to_list() |> length()
  defp infer_dimension([embedding | _]) when is_list(embedding), do: length(embedding)
  defp infer_dimension([_ | rest]), do: infer_dimension(rest)

  defp log_embedder_warning(reason) do
    Logger.warning("Embedding generation failed: #{inspect(reason)}")
  end

  defp log_encoder_warning(reason) do
    Logger.warning("Binary encoder failed: #{inspect(reason)}")
  end
end
