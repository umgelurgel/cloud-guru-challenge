FROM python:3.8-buster

RUN apt-get update

WORKDIR /code
COPY ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
