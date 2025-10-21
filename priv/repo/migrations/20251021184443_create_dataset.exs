defmodule HybridSearch.Repo.Migrations.CreateDataset do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS vector", "DROP EXTENSION IF EXISTS vector")

    create table(:dataset_chunks) do
      add :source_path, :string, null: false
      add :document_title, :string, null: false
      add :chunk_index, :integer, null: false
      add :content, :text, null: false

      add :embedding, :vector, size: 384
      add :embedding_binary, :text

      timestamps(type: :naive_datetime_usec)
    end

    create unique_index(:dataset_chunks, [:source_path, :chunk_index],
             name: :dataset_chunks_source_chunk_index
           )

    create index(:dataset_chunks, [:document_title])

    create index(:dataset_chunks, ["to_tsvector('english', content)"],
             using: :gin,
             name: :dataset_chunks_content_tsv_idx
           )

    execute(
      """
      CREATE INDEX dataset_chunks_embedding_cosine_idx
      ON dataset_chunks
      USING ivfflat (embedding vector_cosine_ops)
      WITH (lists = 100)
      """,
      "DROP INDEX IF EXISTS dataset_chunks_embedding_cosine_idx"
    )

    execute(
      """
      CREATE INDEX dataset_chunks_embedding_l2_idx
      ON dataset_chunks
      USING ivfflat (embedding vector_l2_ops)
      WITH (lists = 100)
      """,
      "DROP INDEX IF EXISTS dataset_chunks_embedding_l2_idx"
    )

    execute(
      """
      CREATE INDEX dataset_chunks_embedding_ip_idx
      ON dataset_chunks
      USING ivfflat (embedding vector_ip_ops)
      WITH (lists = 100)
      """,
      "DROP INDEX IF EXISTS dataset_chunks_embedding_ip_idx"
    )

    execute(
      """
      DO $$
      BEGIN
        BEGIN
          CREATE INDEX dataset_chunks_embedding_l1_idx
          ON dataset_chunks
          USING ivfflat (embedding vector_l1_ops)
          WITH (lists = 100);
        EXCEPTION
          WHEN others THEN
            NULL;
        END;
      END
      $$;
      """,
      "DROP INDEX IF EXISTS dataset_chunks_embedding_l1_idx"
    )

    execute(
      """
      DO $$
      BEGIN
        BEGIN
          CREATE INDEX dataset_chunks_embedding_hamming_idx
          ON dataset_chunks
          USING ivfflat (embedding_binary bit_hamming_ops)
          WITH (lists = 100);
        EXCEPTION
          WHEN others THEN
            NULL;
        END;
      END
      $$;
      """,
      "DROP INDEX IF EXISTS dataset_chunks_embedding_hamming_idx"
    )

    execute(
      """
      DO $$
      BEGIN
        BEGIN
          CREATE INDEX dataset_chunks_embedding_jaccard_idx
          ON dataset_chunks
          USING ivfflat (embedding_binary bit_jaccard_ops)
          WITH (lists = 100);
        EXCEPTION
          WHEN others THEN
            NULL;
        END;
      END
      $$;
      """,
      "DROP INDEX IF EXISTS dataset_chunks_embedding_jaccard_idx"
    )

    execute(
      """
      CREATE OR REPLACE FUNCTION binary_hamming_distance(text, text)
      RETURNS integer
      LANGUAGE SQL
      IMMUTABLE
      AS $$
        SELECT bit_count(CAST($1 AS bit(384)) # CAST($2 AS bit(384)));
      $$;
      """,
      "DROP FUNCTION IF EXISTS binary_hamming_distance(text, text)"
    )

    execute(
      """
      CREATE OR REPLACE FUNCTION binary_jaccard_distance(text, text)
      RETURNS double precision
      LANGUAGE SQL
      IMMUTABLE
      AS $$
        WITH a AS (SELECT CAST($1 AS bit(384)) AS bits_a),
             b AS (SELECT CAST($2 AS bit(384)) AS bits_b)
        SELECT
          CASE
            WHEN bit_count((a.bits_a | b.bits_b)) = 0 THEN 0.0
            ELSE 1.0 - (
              bit_count((a.bits_a & b.bits_b))::double precision /
              NULLIF(bit_count((a.bits_a | b.bits_b)), 0)
            )
          END
        FROM a, b;
      $$;
      """,
      "DROP FUNCTION IF EXISTS binary_jaccard_distance(text, text)"
    )

    execute(
      """
      CREATE OPERATOR <~> (
        PROCEDURE = binary_hamming_distance,
        LEFTARG = text,
        RIGHTARG = text
      )
      """,
      "DROP OPERATOR IF EXISTS <~> (text, text)"
    )

    execute(
      """
      CREATE OPERATOR <%> (
        PROCEDURE = binary_jaccard_distance,
        LEFTARG = text,
        RIGHTARG = text
      )
      """,
      "DROP OPERATOR IF EXISTS <%> (text, text)"
    )
  end
end
