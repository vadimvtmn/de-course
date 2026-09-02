import os
import polars as pl

def save_parquet(df: pl.DataFrame, path: str, partition_by=None) -> None:
    df.write_parquet(path, partition_by=partition_by, mkdir=True)
