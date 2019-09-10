import json
import os

from flask import Flask
app = Flask(__name__)


@app.route('/')
def hello():
    return "Hello World!"


@app.route('/health')
def health():
    return "OK"


@app.route('/env')
def env():
    return json.dumps(dict((k, v) for k, v in os.environ.items() if type(v) == str and len(v) < 64))
