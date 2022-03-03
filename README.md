I'm chasing a bug.  Sometimes, tasks following sensors get stuck in "scheduled" which causes the dag to stay "running" forever.

The files in this repo aim to recreate the bug's native habitat.  Here's how to use them:

1. take a look at setup.txt, it will show you how to get a local cluster running with minikube
2. run stage.sh, it will create an airflow image
3. run deploy.sh, it will deploy airflow into your local cluster and forward port 8081
4. take a browser to http://localhost:8081 and let it run for a while
5. hope the bug appears
