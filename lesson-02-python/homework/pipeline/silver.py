"""Silver stage — clean, filter and de-duplicate the bronze events.

TODO (Завдання 2 і 3): реалізуйте build_silver() і write_silver_partitioned().
Контракт: див. CONTRACTS.md → "silver" і "silver partitioned".

build_silver():
  * залиште тільки типи з config.TARGET_EVENT_TYPES
  * приберіть рядки з порожнім/відсутнім repo_name, відсутнім event_id чи created_at
  * гарантуйте унікальність по event_id (.unique(subset=["event_id"]))
  * запишіть у config.SILVER_FILE і поверніть DataFrame

write_silver_partitioned():
  * запишіть silver як Hive-партиціонований датасет за event_type
  * директорія: config.SILVER_PARTITIONED_DIR
  * підказка: df.write_parquet(dir, partition_by="event_type")
"""

from __future__ import annotations

import polars as pl
import os

from . import config
from .utils import save_parquet


def build_silver(bronze: pl.DataFrame) -> pl.DataFrame:
    df = bronze.drop_nulls(subset=["repo_name", "event_id", "created_at"])

    df = df.filter(
        (pl.col("event_type").is_in(config.TARGET_EVENT_TYPES)) &
        (pl.col("repo_name").str.strip_chars() != "")
    )

    df = df.unique(subset=["event_id"], keep="last")

    save_parquet(df=df, path=config.SILVER_FILE)

    print(f"[silver] saved {os.path.basename(config.SILVER_FILE)}")

    return df


def write_silver_partitioned(silver: pl.DataFrame) -> None:
    save_parquet(df=silver, path=config.SILVER_PARTITIONED_DIR, partition_by=["event_type"])
    print(f"[silver] saved {os.path.basename(config.SILVER_PARTITIONED_DIR)}")