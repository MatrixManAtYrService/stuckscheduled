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
helm repo add apache-airflow https://airflow.apache.org
helm repo add astronomer-airflow https://helm.astronomer.io
helm repo update

# # astro chart
# cat <<- 'EOF' | helm install airflow --namespace tmp astronomer-airflow/airflow -f -
# airflow:
#   airflowHome: /usr/local/airflow
#   executor: CeleryExecutor
#   defaultAirflowRepository: localhost:5000/stuckscheduled
#   defaultAirflowTag: latest
#   gid: 50000
#   images:
#     airflow:
#       pullPolicy: Always
#       repository: localhost:5000/stuckscheduled
#     flower:
#       pullPolicy: Always
#     pod_template:
#       pullPolicy: Always
#   env:
#     - name: AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC
#       value: '2'
#   logs:
#     persistence:
#       enabled: true
#       size: 2Gi
# EOF
cat <<- 'EOF' | helm install airflow --namespace tmp apache-airflow/airflow -f -
executor: CeleryExecutor
defaultAirflowRepository: localhost:5000/stuckscheduled
defaultAirflowTag: latest
images:
  airflow:
    pullPolicy: Always
    repository: localhost:5000/stuckscheduled
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

# deploy postgres
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install test --namespace tmp bitnami/postgresql

# some details we'll need
POSTGRES_PASSWORD=$(kubectl -n tmp get secret test-postgresql -o jsonpath="{.data.postgres-password}" | base64 --decode)
SCHEDULER_POD=$(kubectl -n tmp get pods | grep airflow-scheduler | awk '{print $1}')

# create the connection
kubectl -n tmp exec svc/airflow-webserver bash -- \
    airflow connections add postgres \
        --conn-type postgres \
        --conn-host test-postgresql \
        --conn-login postgres \
        --conn-password $POSTGRES_PASSWORD \
        --conn-schema postgres

# unpause the test dag
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause example_sql_sensor

# unpause a dag which will create background noise
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause sixteen_sleep_grains

# forward the webserver port so that the caller can poke around
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace tmp &

# dump scheduler logs to this file and also the terminal
kubectl -n tmp logs -f $SCHEDULER_POD -c scheduler | tee scheduler.log
