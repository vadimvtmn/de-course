"""Orchestrator — runs the whole pipeline landing -> bronze -> silver -> gold.

Run from the homework directory:

    uv run python run.py

Each stage writes its artifact under homework/data/. Re-running is safe: the
landing download is skipped if present and every table is overwritten.
"""

from __future__ import annotations

import logging

from pipeline import bronze, gold, landing, silver

logger = logging.getLogger(__name__)


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    landing.land_raw_hour()

    bronze_df = bronze.build_bronze()

    silver_df = silver.build_silver(bronze_df)
    silver.write_silver_partitioned(silver_df)

    gold.build_repo_activity(silver_df)
    gold.build_activity_per_minute(silver_df)
    gold.build_push_commits_by_repo(silver_df)

    logger.info("pipeline complete")


if __name__ == "__main__":
    main()
