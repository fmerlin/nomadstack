#!/usr/bin/python
import json
import os
import sys
import time

import psutil

res = []
ret = 0


def conv(val):
    if isinstance(val, str):
        if val[-1] == 'g':
            return float(val[:-1]) * 1024 * 1024 * 1024
        if val[-1] == 'm':
            return float(val[:-1]) * 1024 * 1024
        if val[-1] == 'k':
            return float(val[:-1]) * 1024
    return float(val)


def check(c: list, free: float, percent: float):
    global ret
    threshold_f = conv(c[0])
    threshold_p = conv(c[1])
    if free < threshold_f:
        ret = 2
        msg = 'free is too low'
    elif percent > threshold_p:
        ret = max(ret, 1)
        msg = 'percent is too high'
    else:
        msg = 'OK'
    res.append(dict(msg=msg, free=free, percent=percent, min_free=c[0], max_percent=c[1]))


for c in sys.argv:
    cmd = c.partition(':')
    params = cmd[2][:-1].split(',')
    if cmd == 'RAM':
        st = psutil.virtual_memory()
        check(params, st.free, st.percent)
    if cmd == 'CPU':
        st = psutil.cpu_times()
        st = dict(free=st.idle, user=st.user, total=st.idle + st.user + st.system, time=time.time())
        if os.path.exists('/tmp/cpu.json'):
            with open('/tmp/cpu.json') as f:
                prev = json.load(f)
            check(params,
                  st['idle'] - prev['idle'],
                  100 * (st['user'] - prev['user']) / (st['total'] - prev['total']))
        with open('/tmp/cpu.json', 'w') as f:
            json.dump(st, f)
    if cmd == 'DISK':
        loc = params[0]
        if not os.path.ismount(loc):
            res.append(dict(msg='not mounted', **c))
        else:
            st = psutil.disk_usage(loc)
            check(params[1:], st.free, st.percent)

print(json.dumps(res))
sys.exit(ret)
