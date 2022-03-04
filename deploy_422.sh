#! /usr/bin/env bash

set -x
# clean up previous executions
kubectl delete namespace tmp

# kill lingering port forwards
ps aux | grep '8080:8080 --namespace tmp' | grep -v grep | awk '{print $2}' | xargs kill

set -euo pipefail

# a place to put everything
kubectl create namespace tmp

# deploy airflow
helm repo add astronomer-airflow https://helm.astronomer.io
helm repo update

# astro chart
cat <<- 'EOF' | helm install airflow --namespace tmp apache-airflow/airflow -f -
executor: CeleryExecutor
defaultAirflowRepository: localhost:5000/stuck442
defaultAirflowTag: latest
images:
  airflow:
    pullPolicy: Always
    repository: localhost:5000/stuck442
  flower:
    pullPolicy: Always
  pod_template:
    pullPolicy: Always
env:
  - name: AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC
    value: '2'
logs:
  persistence:
    enabled: true
    size: 2Gi
EOF

# some details we'll need
SCHEDULER_POD=$(kubectl -n tmp get pods | grep airflow-scheduler | awk '{print $1}')

# # create the connection
# # (if my instance isn't still up, you might need to make an elephantsql account, and populate your db's details below)
# kubectl -n tmp exec svc/airflow-webserver bash -- \
#     airflow connections add postgres \
#         --conn-type postgres \
#         --conn-host otto.db.elephantsql.com \
#         --conn-login owpmdtsv \
#         --conn-password jozgKkCEMDaNr1NHAYFH0mA26WUu2FYC \
#         --conn-schema owpmdtsv

# unpause the test dag
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause sensors_a
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause sensors_b
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause sensors_c
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause sensors_d
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause sensors_e

# forward the webserver port so that the caller can poke around
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace tmp &

# dump scheduler logs to this file and also the terminal
kubectl -n tmp logs -f $SCHEDULER_POD -c scheduler | tee scheduler.log
