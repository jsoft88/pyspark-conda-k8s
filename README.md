# Running pyspark with conda on Kubernetes
Hopefully this will help you overcome a very exhausting task I had which
was about executing a pyspark application in a conda environment on 
kubernetes. I've compiled a step by a step guide here, after digging into
Spark source code to figure out the right way. Hope you find it helpful!
:rocket:

## Requirements
* Spark 2.4.6
* Docker
* Minikube
* Miniconda

## Step by step guide
You will need to download spark from the official site, in my case I gave it
a go with this one: [https://archive.apache.org/dist/spark/spark-2.4.6/spark-2.4.6-bin-without-hadoop.tgz](https://archive.apache.org/dist/spark/spark-2.4.6/spark-2.4.6-bin-without-hadoop.tgz).
You can proceed like this:
```shell
> wget https://archive.apache.org/dist/spark/spark-2.4.6/spark-2.4.6-bin-without-hadoop.tgz -O /tmp/spark-2.4.6.tar.gz
> tar -zxf /tmp/spark-2.4.6.tar.gz -C /tmp
> cd /tmp/spark-2.4.6-bin-without-hadoop/bin
```
As stated in the Spark official docs ([Spark on kubernetes](https://spark.apache.org/docs/2.4.6/running-on-kubernetes.html)),
you will need to make use of `docker-image-tool.sh` to generate the base docker images, upon which you
could further customize later. So to use a repo in dockerhub, you would invoke the script
like this:
```shell
> ./docker-image-tool.sh -r jsoft88 -t 2.4.6 build
> ./docker-image-tool.sh -r jsoft88 -t 2.4.6 push
```

Now, let's take a look at what the Dockerfile customised to the sample project
in this repo looks like:
```dockerfile
FROM jsoft88/spark-py:2.4.6

ENV PATH="/opt/miniconda3/bin:${PATH}"
ARG PATH="/opt/miniconda3/bin:${PATH}"

WORKDIR /home/bitnami

RUN apt update -y && apt install wget -y && wget https://repo.anaconda.com/miniconda/Miniconda3-py37_4.8.2-Linux-x86_64.sh -O miniconda.sh

RUN chmod +x ./miniconda.sh

RUN ./miniconda.sh -b -f -p /opt/miniconda3

RUN rm -f miniconda.sh

RUN /opt/miniconda3/bin/conda init bash

COPY . /home/bitnami/spark-sample

RUN conda config --add channels conda-forge

RUN conda create --name spark_env --file /home/bitnami/spark-sample/requirements.txt --yes python=3.7.3

RUN . /opt/miniconda3/etc/profile.d/conda.sh && conda activate spark_env && cd /home/bitnami/spark-sample && pip install .

RUN wget https://archive.apache.org/dist/spark/spark-2.4.6/spark-2.4.6-bin-without-hadoop.tgz -O /home/bitnami/spark-2.4.6.tar.gz

RUN tar -zxf /home/bitnami/spark-2.4.6.tar.gz && rm -rf /home/bitnami/spark-2.4.6.tar.gz

RUN cp /home/bitnami/spark-2.4.6-bin-without-hadoop/kubernetes/dockerfiles/spark/entrypoint.sh .

RUN rm -rf /home/bitnami/spark-2.4.6-bin-without-hadoop/

# Alter entrypoint.sh from base image to activate conda env
RUN sed -i 's/set -ex/set -ex \&\& conda init bash \&\& \. \/opt\/miniconda3\/etc\/profile\.d\/conda\.sh \&\& conda activate spark_env/' entrypoint.sh && chmod +x entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]
```

In the Dockerfile, I once again pull spark binaries, since the `entrypoint.sh` is not prepared
to work with a virtual environment, so I need to insert so modifications into this script
as in this line `RUN sed -i 's/set -ex/set -ex \&\& conda init bash \&\& \...`, where the
installed conda in the container is initialized, activated and can be used when deployed onto a pod.

Finally, it is time to build the docker image and push it to the repo, so that
once the pod is deployed, it can retrieve it from there.

## Submitting the spark application
For submitting the application, you need to have spark binaries, and since we needed this to build
the base docker images, it is already available to you. So to run the application:
```shell
> cd /tmp/spark-2.4.6-bin-without-hadoop/bin
> ./bin/spark-submit --master k8s://https://127.0.0.1:49154 \
    --deploy-mode cluster \
    --name pyspark-on-k8s \
    --conf spark.executor.instances=1 \
    --conf spark.kubernetes.driver.container.image=jsoft88/conda_spark:2.4.6 \
    --conf spark.kubernetes.executor.container.image=jsoft88/conda_spark:2.4.6 \
    --conf spark.kubernetes.pyspark.pythonVersion=3 \
    --conf spark.kubernetes.driverEnv.PYSPARK_DRIVER_PYTHON=/opt/miniconda3/envs/spark_env/bin/python \
    --conf spark.kubernetes.driverEnv.PYSPARK_PYTHON=/opt/miniconda3/envs/spark_env/bin/python \
    --conf spark.kubernetes.driverEnv.PYTHON_VERSION=3.7.3 \
    --conf spark.kubernetes.driverEnv.SPARK_HOME=/opt/miniconda3/envs/spark_env/lib/python3.7/site-packages/pyspark \
    --conf spark.kubernetes.container.image.pullPolicy=Always \
    --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
    /home/bitnami/spark-sample/app/main/sample_app.py --top 10
```

Notice the last line in the spark-submit part is a directory inside the docker container.
You can check spark official docs for the different `conf`s that you can provide via CLI, but
most of the configs passed here are quite self-explanatory.

__IMPORTANT__: You need to define a service account and give this service account the edit
role on the cluster. In the context of Minikube, this is what it looks like:

```shell
> kubectl create serviceaccount spark
> kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

Notice that this service account is provided as conf in the spark-submit part: 
`--conf spark.kubernetes.authenticate.driver.serviceAccountName=spark`.


And...


VOILA! All done, you have scheduled your first pyspark app on Kubernetes!
