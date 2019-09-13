import json
import logging
import os
from io import BytesIO
import msgpack
from fluent import handler


def setup():
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

    logging.basicConfig(level=logging.INFO)
    config = json.loads(os.environ['FLUENTD'])
    fluenthandler = handler.FluentHandler(os.environ['SERVICE_NAME'], host=config.host, port=config.port,
                                          buffer_overflow_handler=overflow_handler)
    formatter = handler.FluentRecordFormatter(custom_format)
    fluenthandler.setFormatter(formatter)
    l = logging.getLogger()
    l.addHandler(fluenthandler)
    l.setLevel(config.level or "INFO")
