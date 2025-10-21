defmodule HybridSearch.Datasets.DatasetChunk do
  @moduledoc """
  Represents a chunk of source content stored in the dataset.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type embedding_vector :: Pgvector.Ecto.Vector.t() | nil
  @binary_length 384

  @type t :: %__MODULE__{
          id: integer(),
          source_path: String.t(),
          document_title: String.t(),
          chunk_index: non_neg_integer(),
          content: String.t(),
          embedding: embedding_vector,
          embedding_binary: String.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "dataset_chunks" do
    field :source_path, :string
    field :document_title, :string
    field :chunk_index, :integer
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector
    field :embedding_binary, :string

    timestamps(type: :naive_datetime_usec)
  end

  @doc false
  def changeset(chunk \\ %__MODULE__{}, attrs) do
    chunk
    |> cast(attrs, [
      :source_path,
      :document_title,
      :chunk_index,
      :content,
      :embedding,
      :embedding_binary
    ])
    |> validate_required([:source_path, :document_title, :chunk_index, :content])
    |> validate_number(:chunk_index, greater_than_or_equal_to: 0)
    |> validate_length(:embedding_binary, is: @binary_length, count: :graphemes)
    |> unique_constraint(:chunk_index,
      name: :dataset_chunks_source_chunk_index,
      message: "duplicate chunk for source file"
    )
  end
end
