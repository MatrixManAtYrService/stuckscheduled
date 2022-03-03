#! /usr/bin/env bash

set -x
# clean up previous executions
kubectl delete namespace tmp

# kill lingering port forwards
ps aux | grep '8081:8080 --namespace tmp' | grep -v grep | awk '{print $2}'

set -euo pipefail

# a place to put everything
kubectl create namespace tmp

# deploy airflow
helm repo add apache-airflow https://airflow.apache.org
helm repo update
cat <<- 'EOF' | helm install airflow --namespace tmp apache-airflow/airflow -f -
defaultAirflowRepository: localhost:5000/stuckscheduled
defaultAirflowTag: latest
env:
  - name: AIRFLOW__SCHEDULER__SCHEDULER_HEARTBEAT_SEC
    value: '2'
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
kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause thirty_three_sleep_grains

# forward the webserver port so that the caller can poke around
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace tmp &

# dump scheduler logs to this file and also the terminal
kubectl -n tmp logs -f $SCHEDULER_POD -c scheduler | tee scheduler.log