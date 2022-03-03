from copy import deepcopy
from dataclasses import dataclass
from datetime import datetime, timedelta
from multiprocessing import Pool, cpu_count
from random import randint, seed
from time import sleep, time
from typing import Union, List

import numpy
from airflow.models.taskmixin import TaskMixin
from airflow.decorators import dag, task
from airflow.operators.dummy import DummyOperator
from airflow.operators.python import PythonOperator
from airflow.utils.helpers import chain

# worktypes

cpu = "cpu"
memory = "memory"
zzz = "sleep"
kpo_zzz = "kubernetes_pod_operator_sleep"


@dataclass
class Shape:
    length_sec: int
    width_tasks: int
    min_pieces: int
    max_pieces: int
    worktype: str
    seed: int


# callables
def sleep_step(n):
    print(f"sleeping {n}")
    sleep(n)
    print("    done")


def cpu_step(n):
    cores = cpu_count()
    now = time()
    stop_at = now + n

    def work(x):
        while True:
            if time() > stop_at:
                break
            x * x

    print(f"it's {now}, working until {stop_at} (using {cores} cores)")
    pool = Pool(cores)
    pool.map(work, range(cores))


def mem_bomb():
    print("allocating a terrabyte of memory...")
    numpy.ones((1_000_000_000_000))
    print("you probably didn't get this far")


def make_lanes(upstream: TaskMixin, shape: Shape):

    lanes = []
    for lane_num in range(1, shape.width_tasks + 1):
        worker_ct = randint(shape.min_pieces, shape.max_pieces)

        chunks = [randint(1, 10) for _ in range(worker_ct)]
        total = sum(chunks)
        if shape.length_sec:
            durations = [int(shape.length_sec * (c / total)) for c in chunks]
        else:
            durations = [1]
        lane = []
        for i, worklen in enumerate(durations):
            if shape.worktype == zzz:
                lane.append(
                    PythonOperator(
                        task_id=f"{lane_num}.{i}_sleep_{worklen}",
                        python_callable=sleep_step,
                        op_args=[worklen],
                    )
                )
            elif shape.worktype == cpu:
                lane.append(
                    PythonOperator(
                        task_id=f"{lane_num}.{i}_cpu_{worklen}",
                        python_callable=cpu_step,
                        op_args=[worklen],
                    )
                )
            elif shape.worktype == memory:
                lane.append(
                    PythonOperator(
                        task_id=f"{lane_num}.{i}_mem_bomb",
                        python_callable=mem_bomb,
                    )
                )
            elif shape.worktype == kpo_zzz:
                raise NotImplemented("kpo coming soon")
            else:
                raise Exception(f"what's a {shape.worktype}?")
        chain(*lane)
        upstream >> lane[0]


def make_stressball(name: str, shape: Union[Shape, List[Shape]]):
    @dag(
        dag_id=name,
        start_date=datetime(1970, 1, 1),
        schedule_interval=timedelta(seconds=307),
        max_active_runs=1,
        catchup=False,
    )
    def stressball():

        # initalize rng

        start = DummyOperator(task_id="start")

        # populate worker lanes
        if type(shape) == list:
            seed(sum([s.seed for s in shape]))
            for i, s in enumerate(shape):
                print(i, end=":")
                make_lanes(start, s)
        else:
            seed(shape.seed)
            make_lanes(start, shape)

    return stressball()


s_15_sleep = Shape(
    length_sec=60, width_tasks=15, min_pieces=1, max_pieces=1, worktype=zzz, seed=0
)
s_15_sleep_dag = make_stressball("fifteen_sleep", s_15_sleep)

s_16_sleep = deepcopy(s_15_sleep)
s_16_sleep.width_tasks = 16
s_16_sleep_dag = make_stressball("sixteen_sleep", s_16_sleep)

s_17_sleep = deepcopy(s_15_sleep)
s_17_sleep.width_tasks = 17
s_17_sleep_dag = make_stressball("seventeen_sleep", s_17_sleep)

s_33_sleep = deepcopy(s_15_sleep)
s_33_sleep.width_tasks = 33
s_33_sleep_dag = make_stressball("thirty_three_sleep", s_33_sleep)

s_16_sleep_grains = deepcopy(s_16_sleep)
s_16_sleep_grains.min_pieces = 2
s_16_sleep_grains.max_pieces = 10
s_16_sleep_grains.seed = 42
s_16_sleep_grains = make_stressball("sixteen_sleep_grains", s_16_sleep_grains)

s_17_sleep_grains = deepcopy(s_17_sleep)
s_17_sleep_grains.min_pieces = 2
s_17_sleep_grains.max_pieces = 10
s_17_sleep_grains.seed = 43
s_17_sleep_grains = make_stressball("seventeen_sleep_grains", s_17_sleep_grains)

s_33_sleep_grains = deepcopy(s_33_sleep)
s_33_sleep_grains.min_pieces = 2
s_33_sleep_grains.max_pieces = 10
s_33_sleep_grains.seed = 44
s_33_sleep_grains = make_stressball("thirty_three_sleep_grains", s_33_sleep_grains)

s_17_kpo = deepcopy(s_17_sleep)
s_17_kpo.worktype = kpo_zzz
# TODO

s_33_kpo = deepcopy(s_33_sleep)
s_33_kpo.worktype = kpo_zzz
# TODO

s_mem = Shape(
    length_sec=None, width_tasks=1, min_pieces=1, max_pieces=1, worktype=memory, seed=0
)

# 15 tasks, one memory explosion
s_16_1mem = [deepcopy(s_15_sleep), s_mem]
s_16_1mem = make_stressball("sixteen_sleep_one_membomb", s_16_1mem)

s_16_cpu = deepcopy(s_16_sleep)
s_16_cpu.worktype = cpu
s_16_cpu = make_stressball("sixteen_cpu", s_16_cpu)
