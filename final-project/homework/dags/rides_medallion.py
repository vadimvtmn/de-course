"""DAG: Bronze (Spark) -> Silver -> Gold -> reconcile. ЕТАП 3, SPEC.md, розділ 5.

Контейнер Airflow має Java, pyspark, JDBC-драйвер і dbt (в окремому venv, див.
docker/Dockerfile.airflow). Проєкт змонтовано в /opt/airflow/project.

Стан «що вже оброблено» живе в даних, а не в розкладі: Bronze пропускає файли, які вже
є в bronze.raw_events (`_source_file`), а dbt-моделі беруть рядки з `_ingested_at` вищим за
власний high watermark. Тому `data_interval_start/end` тут не потрібні: повторний запуск без
нових файлів нічого не змінює, а ретрай будь-якої задачі безпечний.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

PROJECT = "/opt/airflow/project"
DBT_BIN = "/home/airflow/dbt-venv/bin/dbt"  # dbt у окремому venv
# target/ і logs/ пишемо в /tmp контейнера, щоб не смітити у змонтованому проєкті.
DBT = f"cd {PROJECT} && DBT_TARGET_PATH=/tmp/dbt-target DBT_LOG_PATH=/tmp/dbt-logs {DBT_BIN}"
DBT_DIRS = "--project-dir dbt_rides --profiles-dir dbt_rides"
# Тест із parent-ами;
CAUTIOUS = "--indirect-selection cautious"

default_args = {
    "owner": "vadym",
    "retries": 1,
    "retry_delay": timedelta(minutes=1),
    "execution_timeout": timedelta(minutes=30),
}

with DAG(
    dag_id="rides_medallion",
    description="landing -> Bronze (Spark) -> Silver -> Gold (dbt) -> звірка між шарами",
    schedule="*/5 * * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["medallion", "rides"],
) as dag:
    bronze_spark = BashOperator(
        task_id="bronze_spark",
        bash_command=f"cd {PROJECT} && python bronze_job.py",
    )

    bronze_contract = BashOperator(
        task_id="bronze_contract",
        bash_command=f"{DBT} test --select source:bronze {DBT_DIRS}",
    )

    silver = BashOperator(
        task_id="silver",
        bash_command=f"{DBT} build --selector silver {CAUTIOUS} {DBT_DIRS}",
    )

    gold = BashOperator(
        task_id="gold",
        bash_command=f"{DBT} build --selector gold {CAUTIOUS} {DBT_DIRS}",
    )

    reconcile = BashOperator(
        task_id="reconcile",
        bash_command=f"{DBT} test --selector reconcile {DBT_DIRS}",
    )

    bronze_spark >> bronze_contract >> silver >> gold >> reconcile
