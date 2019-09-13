import json
import os
import time
from threading import Thread
import consul


class ConsulConfig:
    def __init__(self, key):
        self.config = json.loads(os.environ['CONSUL'])
        self.key = key
        self.token = os.environ['CONSUL_HTTP_TOKEN']
        self.data = dict()
        self.t = None

    def _recursive_set(self, d, keys, value):
        k = keys[0]
        v = d.get(k)
        if len(keys) == 1:
            if v == value:
                return False
            d[k] = value
            return True
        else:
            if v is None or type(v) is not dict:
                v = {}
                d[k] = v
            return self._recursive_set(v, keys[1:], value)

    def load(self):
        index = 0
        nb_root_keys = len(self.key.split('/'))
        while True:
            c = consul.Consul(host=self.config.host, port=self.config.port, token=self.token)
            try:
                while True:
                    index, items = c.kv.get(self.key, recurse=True, index=index)
                    for item in items:
                        self._recursive_set(self.data, item['key'].split('/')[nb_root_keys:], item['Value'])
            except:
                time.sleep(10)

    def start(self):
        self.t = Thread(target=self.load)
        self.t.start()

    def join(self):
        self.t.join()

    def __getitem__(self, item):
        return self.data.get(item)
