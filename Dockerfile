FROM python:3.8-buster

RUN apt-get update

WORKDIR /code
COPY ./requirements.txt requirements.txt
COPY ./requirements-dev.txt requirements-dev.txt
RUN pip install -r requirements.txt
RUN pip install -r requirements-dev.txt
