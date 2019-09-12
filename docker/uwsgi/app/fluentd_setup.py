import json
import logging
import os
from io import BytesIO
import msgpack
from fluent import handler

custom_format = dict(
    hostname='%(hostname)s',
    module='%(funcName)s',
    funcName='%(funcName)s',
    levelName='%(levelname)s',
    stackTrace='%(exc_text)s'
)


def overflow_handler(pendings):
    unpacker = msgpack.Unpacker(BytesIO(pendings))
    for unpacked in unpacker:
        print(unpacked)


def getHandler():
  global fluenthandler
  if fluenthandler is None:
    logging.basicConfig(level=logging.INFO)
    config = json.loads(os.environ['FLUENTD'])
    fluenthandler = handler.FluentHandler(os.environ['SERVICE_NAME'], host=config.host, port=config.port,
                                          buffer_overflow_handler=overflow_handler)
    formatter = handler.FluentRecordFormatter(custom_format)
    fluenthandler.setFormatter(formatter)
  return fluenthandler


def getLogger(name):
    l = logging.getLogger(name)
    l.addHandler(getHandler())
    return l
