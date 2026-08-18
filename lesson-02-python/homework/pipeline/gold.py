"""Gold stage — three analytics tables built from silver.

TODO (Завдання 4, 5, 6): реалізуйте три функції нижче.
Контракт: див. CONTRACTS.md → "gold repo_activity", "gold activity_per_minute",
"gold push_commits_by_repo". Усі лічильники приводьте до Int64 (.cast(pl.Int64)),
щоб схема результату була стабільною.

  * build_repo_activity:        кількість подій + кількість унікальних типів на repo
  * build_activity_per_minute:  кількість подій по хвилинах (.dt.truncate("1m"))
  * build_push_commits_by_repo: тільки PushEvent — кількість пушів і сума commit_count на repo
"""

from __future__ import annotations

import polars as pl
import logging
import os

from . import config
from .utils import save_parquet

logger = logging.getLogger(__name__)


def build_repo_activity(silver: pl.DataFrame) -> pl.DataFrame:
    df = silver.group_by("repo_name").agg(
        pl.len().alias("event_count"),
        pl.col("event_type").n_unique().alias("distinct_event_types")
    )

    df = df.sort("event_count", descending=True)

    df = df.with_columns(
        pl.col("event_count").cast(pl.Int64),
        pl.col("distinct_event_types").cast(pl.Int64)
    )

    save_parquet(df=df, path=config.GOLD_REPO_ACTIVITY)

    logger.info("saved %s", os.path.basename(config.GOLD_REPO_ACTIVITY))

    return df


def build_activity_per_minute(silver: pl.DataFrame) -> pl.DataFrame:
    df = silver.with_columns(pl.col("created_at").dt.truncate("1m").alias("minute"))

    df = df.group_by("minute").agg(
        pl.len().alias("event_count")
    )

    df = df.sort("minute")

    df = df.with_columns(
        pl.col("event_count").cast(pl.Int64)
    )

    save_parquet(df=df, path=config.GOLD_ACTIVITY_PER_MINUTE)

    logger.info("saved %s", os.path.basename(config.GOLD_ACTIVITY_PER_MINUTE))

    return df


def build_push_commits_by_repo(silver: pl.DataFrame) -> pl.DataFrame:
    df = silver.filter(pl.col("event_type")=="PushEvent")

    df = df.group_by("repo_name").agg(
        pl.len().alias("push_events"),
        pl.col("commit_count").sum().alias("total_commits")
    )

    df = df.with_columns(
        pl.col("push_events").cast(pl.Int64),
        pl.col("total_commits").cast(pl.Int64)
    )

    save_parquet(df=df, path=config.GOLD_PUSH_COMMITS)

    logger.info("saved %s", os.path.basename(config.GOLD_PUSH_COMMITS))

    return df
