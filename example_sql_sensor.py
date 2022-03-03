from airflow.models import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.sensors.sql import SqlSensor
from datetime import date, timedelta, datetime

DATES = []
for i in range(6):
    DATES.append((date.today() - timedelta(days=i)).strftime("%Y-%m-%d"))

TABLE = "checktuuuy"
DROP = f"DROP TABLE IF EXISTS {TABLE} CASCADE;"
CREATE = f"CREATE TABLE IF NOT EXISTS {TABLE}(state varchar, temp integer, date date)"
INSERT = f"""
INSERT INTO {TABLE}(state, temp, date)
VALUES ('Lagos', 23, '{DATES[4]}'),
    ('Enugu', 25, '{DATES[3]}'),
    ('Delta', 25, '{DATES[2]}'),
    ('California', 28, '{DATES[1]}'),
    ('Abuja', 25, '{DATES[0]}')
"""

SQLBOOL_QUERY = f"""
SELECT CAST(CASE WHEN COUNT(*) > 0 THEN 1 ELSE 0 END AS BIT)
FROM {TABLE} WHERE temp = 30;
"""


def prepare_data():
    postgres = PostgresHook("postgres")
    with postgres.get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(DROP)
            cur.execute(CREATE)
            cur.execute(INSERT)
        conn.commit()


def temp(name):
    return name == "Abia"


with DAG(
    dag_id="example_sql_sensor",
    start_date=datetime(1970, 1, 1),
    schedule_interval=timedelta(seconds=181),
    max_active_runs=1,
    catchup=False,
) as dag:

    t1 = PythonOperator(task_id="prepare_table", python_callable=prepare_data)

    t2 = BashOperator(task_id="sleep_30", bash_command="sleep 30")

    t3 = PostgresOperator(
        postgres_conn_id="postgres",
        task_id="add_state",
        sql=f"INSERT INTO {TABLE} (state, temp, date) VALUES ('Abia', 25, '{DATES[5]}')",
    )
    t4 = SqlSensor(
        task_id="sql_sensor",
        conn_id="postgres",
        sql=f"SELECT * FROM {TABLE} WHERE state='Abia'",
        parameters=["state", "temp", "date"],
        success=temp,
    )

    t5 = PostgresOperator(
        postgres_conn_id="postgres",
        task_id="drop_table_last",
        sql=DROP,
        trigger_rule="all_done",
    )
    t1 >> t2 >> t3 >> t5
    t1 >> t4 >> t5
