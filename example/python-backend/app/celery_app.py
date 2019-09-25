import json
import os
from celery import Celery


app = Celery()
with open(os.getenv("CELERY_CONFIG_FILE")) as f:
    app.conf.update(**json.load(f))


@app.task
def hello():
    return "Hello World!"


@app.task
def add(x, y):
    return x + y
