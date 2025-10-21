defmodule HybridSearch.Repo.Migrations.AddBinaryDistanceFunctions do
  use Ecto.Migration

  def change do
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
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_catalog.pg_operator
          WHERE oprname = '<~>' AND oprleft = 'text'::regtype AND oprright = 'text'::regtype
        ) THEN
          CREATE OPERATOR <~> (
            PROCEDURE = binary_hamming_distance,
            LEFTARG = text,
            RIGHTARG = text
          );
        END IF;
      END
      $$;
      """,
      "DROP OPERATOR IF EXISTS <~> (text, text)"
    )

    execute(
      """
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_catalog.pg_operator
          WHERE oprname = '<%>' AND oprleft = 'text'::regtype AND oprright = 'text'::regtype
        ) THEN
          CREATE OPERATOR <%> (
            PROCEDURE = binary_jaccard_distance,
            LEFTARG = text,
            RIGHTARG = text
          );
        END IF;
      END
      $$;
      """,
      "DROP OPERATOR IF EXISTS <%> (text, text)"
    )
  end
end
