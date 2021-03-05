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