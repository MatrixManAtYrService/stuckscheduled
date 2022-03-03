#FROM apache/airflow:2.2.4-python3.9
FROM quay.io/astronomer/ap-airflow-dev:main-62735
COPY example_sql_sensor.py dags/example_sql_sensor.py
COPY stressballs.py dags/stressballs.py
