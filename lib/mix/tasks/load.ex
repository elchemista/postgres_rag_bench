defmodule Mix.Tasks.HybridSearch.Load do
  use Mix.Task

  @shortdoc "Load dataset markdown files into the database"
  @moduledoc """
  Mix task that reads Markdown files from `priv/data` and stores them as dataset chunks,
  generating embeddings with the vendored Bumblebee `thenlper/gte-small` model by default.

  Usage:

      mix hybrid_search.load
      mix hybrid_search.load --dir path/to/files --glob \"*.md\"
  """

  alias HybridSearch.Datasets.Loader

  @switches [
    dir: :string,
    glob: :string
  ]

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, _invalid} = OptionParser.parse(args, switches: @switches, aliases: [d: :dir])

    directory = opts[:dir] || default_data_dir()
    glob = opts[:glob] || "*.md"

    case Loader.load_directory(directory, glob: glob) do
      {:ok, %{files: files, chunks: chunks}} ->
        Mix.shell().info("Loaded #{chunks} chunks from #{files} files.")

      {:error, %{errors: errors} = result} ->
        Mix.shell().error(
          "Loaded #{result.chunks} chunks from #{result.files} files with errors:"
        )

        Enum.each(errors, fn {path, reason} ->
          Mix.shell().error("  #{path}: #{format_error(reason)}")
        end)

      {:error, reason} ->
        Mix.shell().error("Failed to load dataset: #{format_error(reason)}")
    end
  end

  defp default_data_dir do
    Application.app_dir(:hybrid_search, "priv/data")
  end

  defp format_error(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_error({idx, reason}), do: "embedding #{idx}: #{inspect(reason)}"
  defp format_error(reason), do: inspect(reason)
end
