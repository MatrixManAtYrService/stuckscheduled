from airflow import DAG
from datetime import datetime, timedelta
from airflow.sensors.bash import BashSensor
from airflow.operators.dummy import DummyOperator
from airflow.operators.bash import BashOperator


def get_waiter(a, i):
    with DAG(
        f"sensors_{a}",
        start_date=datetime(1970, 1, 1),
        schedule_interval=timedelta(seconds=i),
        max_active_runs=1,
        catchup=False,
    ) as dag:
        [
            BashSensor(
                task_id=f"sleep_{j}",
                bash_command=f"sleep {j} && python -c 'import random, sys; sys.exit(random.randint(0,1))'",
            )
            >> BashOperator(task_id=f"done_{j}", bash_command="echo done")
            for j in range(5)
        ] >> DummyOperator(task_id="done_all")
    return dag


# just some primes for maximal chaos
a = get_waiter("a", 41)
b = get_waiter("b", 53)
c = get_waiter("c", 67)
d = get_waiter("d", 73)
e = get_waiter("e", 97)
