# HybridSearch

HybridSearch is a playground for comparing different PostgreSQL search strategies:

- Full‑text search with BM25 ranking
- Dense vector similarity (cosine, L2, L1, inner product) using `pgvector`
- Binary vector similarity (Hamming / Jaccard) built from the same embeddings

## Prerequisites

- Elixir ≥ 1.18, Erlang/OTP ≥ 27
- PostgreSQL 16+ with the [`vector`](https://github.com/pgvector/pgvector) extension installed
- (Optional) GPU or CPU with AVX support if you plan to enable EXLA for faster embeddings

## Setup

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
```

These commands install dependencies, create the database, and run migrations.

### Embedding model

Embeddings are generated with [`thenlper/gte-small`](https://huggingface.co/thenlper/gte-small) using Bumblebee.  
The loader fetches the model from Hugging Face (`{:hf, "thenlper/gte-small"}`) and caches it under `~/.cache/bumblebee/`.

## Loading markdown data

Put your `.md` files in `priv/data/`. To ingest them:

```bash
mix hybrid_search.load
# or specify a different directory / glob
mix hybrid_search.load --dir /path/to/md --glob "**/*.md"
```

During loading we:

1. Split each markdown file into paragraph-sized chunks.
2. Generate dense embeddings with Bumblebee (vector length 384).
3. Convert the dense vector to a binary `0/1` string for Hamming/Jaccard search.
4. Upsert everything into `dataset_chunks`.

You can also call the loader from IEx:

```elixir
{:ok, stats} = HybridSearch.load_dataset()
```

## Running searches

Start an iex session with the application loaded:

```bash
iex -S mix
```

Example helpers (all functions live under `HybridSearch`):

```elixir
# Full text (BM25)
HybridSearch.search_bm25("liveview")

# Dense vector searches
HybridSearch.search_embeddings("liveview")        # cosine distance
HybridSearch.search_embeddings_l2("liveview")     # L2 / Euclidean
HybridSearch.search_embeddings_l1("liveview")     # L1 / Manhattan
HybridSearch.search_embeddings_dot("liveview")    # inner product (larger is better)

# Binary similarity
HybridSearch.search_embeddings_hamming("liveview")   # Hamming distance over bitstrings
HybridSearch.search_embeddings_jaccard("liveview")   # Jaccard distance over bitstrings
```

Each search returns a list of maps containing:

- `:chunk` – the `%HybridSearch.Datasets.DatasetChunk{}` row
- `:distance` or `:score` – the metric used for ordering
- Additional fields such as `:headline` for BM25

## Notes on benchmarking

- All dense searches rely on the `embedding` column (pgvector 384).
- Binary searches use the `embedding_binary` text column and custom SQL functions:
  - `binary_hamming_distance/2`
  - `binary_jaccard_distance/2`
- IVFFlat indexes are created where supported. If your pgvector build does not include the optional operator classes (e.g. `vector_l1_ops`, `bit_hamming_ops`), the migration skips those indexes gracefully.

## Development commands

```bash
mix test          # run the test suite
mix precommit     # compile w/ warnings-as-errors, format, tests
```

## License

This project is released under the MIT License. See `LICENSE` for details.
