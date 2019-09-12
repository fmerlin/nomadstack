import time

import consul


class ConsulConfig:
    def __init__(self, key, host, port, token):
        self.key = key
        self.host = host
        self.port = port
        self.token = token
        self.data = dict()

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
            c = consul.Consul(host=self.host, port=self.port, token=self.token)
            try:
                while True:
                    index, items = c.kv.get(self.key, recurse=True, index=index)
                    for item in items:
                        self._recursive_set(self.data, item['key'].split('/')[nb_root_keys:], item['Value'])
            except:
                time.sleep(10)
