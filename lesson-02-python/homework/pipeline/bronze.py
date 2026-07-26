"""Bronze stage — read the raw NDJSON and flatten it to one wide table.

TODO (Завдання 1): реалізуйте build_bronze().
Контракт колонок та типів: див. CONTRACTS.md → "bronze".

Підказки:
  * читайте NDJSON ліниво: pl.scan_ndjson(config.LANDING_FILE, schema=config.LANDING_SCHEMA)
  * розгортайте вкладені структури через .struct.field("...")
  * created_at -> datetime: .str.to_datetime("%Y-%m-%dT%H:%M:%SZ", time_zone="UTC")
  * commit_count: довжина списку payload.commits; для не-PushEvent коміти
    відсутні -> заповніть 0 (.list.len().fill_null(0))
  * запишіть результат у config.BRONZE_FILE (Parquet) і поверніть DataFrame
"""

from __future__ import annotations

import polars as pl
import gzip
import os

from . import config
from .utils import save_parquet

def build_bronze() -> pl.DataFrame:
    with gzip.open(config.LANDING_FILE, "rt", encoding="utf-8") as f:
        df = pl.scan_ndjson(f, schema=config.LANDING_SCHEMA)

    df = df.with_columns(
        pl.col("id").alias("event_id"),
        pl.col("type").alias("event_type"),
        pl.col("actor").struct.field("id").alias("actor_id").cast(pl.Int64),
        pl.col("actor").struct.field("login").alias("actor_login").cast(pl.String),
        pl.col("repo").struct.field("id").alias("repo_id").cast(pl.Int64),
        pl.col("repo").struct.field("name").alias("repo_name").cast(pl.String), 
        pl.col("created_at").str.to_datetime(format="%Y-%m-%dT%H:%M:%SZ", time_zone="UTC"),
        pl.col("payload").struct.field("action").alias("action").cast(pl.String),
        pl.col("payload").struct.field("commits").list.len().fill_null(0).alias("commit_count").cast(pl.Int64),     
      )

    df = df.select([
        "event_id", "event_type", "actor_id", "actor_login", "repo_id", 
        "repo_name", "created_at", "public", "action", "commit_count"
      ])

    df = df.collect()

    save_parquet(df=df, path=config.BRONZE_FILE)

    print(f"[bronze] saved {os.path.basename(config.BRONZE_FILE)}")
    return df
