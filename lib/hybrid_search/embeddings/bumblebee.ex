defmodule HybridSearch.Embeddings.Bumblebee do
  @moduledoc """
  Small wrapper around Bumblebee's `thenlper/gte-small` embedding model.
  """

  alias Bumblebee.Text
  alias Nx.Serving
  alias Nx

  @serving_key {__MODULE__, :serving}
  @batch_size 16
  @sequence_length 512

  @spec embed([String.t()]) :: {:ok, [[number()]]} | {:error, term()}
  def embed([]), do: {:ok, []}

  def embed(texts) when is_list(texts) do
    embeddings =
      texts
      |> Enum.map(fn text ->
        serving()
        # serving first, input second
        |> Serving.run(text)
        |> flatten_embedding()
      end)

    {:ok, embeddings}
  rescue
    error -> {:error, error}
  end

  defp serving do
    case :persistent_term.get(@serving_key, :undefined) do
      :undefined ->
        :persistent_term.put(@serving_key, build_serving())
        serving()

      serving ->
        serving
    end
  end

  defp build_serving do
    maybe_enable_exla()

    {:ok, model_info} = Bumblebee.load_model({:hf, "thenlper/gte-small"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "thenlper/gte-small"})

    {:ok, serving} =
      Text.TextEmbedding.text_embedding(
        model_info,
        tokenizer,
        compile: [batch_size: @batch_size, sequence_length: @sequence_length],
        defn_options: if(Code.ensure_loaded?(EXLA.Backend), do: [compiler: EXLA], else: []),
        output_attribute: :hidden_state,
        output_pool: :mean_pooling
      )

    serving
  end

  # Handles both %{embedding: t} and raw tensor returns
  defp flatten_embedding(%{embedding: %Nx.Tensor{} = t}), do: flatten_tensor(t)
  defp flatten_embedding(%Nx.Tensor{} = t), do: flatten_tensor(t)

  defp flatten_tensor(tensor) do
    tensor
    |> Nx.reshape({Nx.size(tensor)})
    |> Nx.to_flat_list()
  end

  defp maybe_enable_exla do
    if Code.ensure_loaded?(EXLA.Backend) do
      {:ok, _} = Application.ensure_all_started(:exla)
      Nx.Defn.global_default_options(compiler: EXLA, client: :host)
    end
  end
end
