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

# apache chart
cat <<- 'EOF' | helm install airflow --namespace tmp astronomer-airflow/airflow -f -
airflow:
  airflowHome: /usr/local/airflow
  executor: CeleryExecutor
  defaultAirflowRepository: localhost:5000/stuckmain
  defaultAirflowTag: latest
  gid: 50000
  images:
    airflow:
      pullPolicy: Always
      repository: localhost:5000/stuckmain
    flower:
      pullPolicy: Always
    pod_template:
      pullPolicy: Always
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

# forward the webserver port so that the caller can poke around
kubectl port-forward svc/airflow-webserver 8080:8080 --namespace tmp &

# unpause the test dag
for x in a b c d e
do
    kubectl -n tmp exec svc/airflow-webserver bash -- airflow dags unpause sensors_${x}
done


# dump scheduler logs to this file and also the terminal
kubectl -n tmp logs -f $SCHEDULER_POD -c scheduler | tee scheduler.log
