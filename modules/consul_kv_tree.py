import consul
import json
import os
from ansible.module_utils.basic import AnsibleModule


def kv_put_one(c, k, v, check_mode):
    v2 = c.kv.get(k)
    if v != v2:
        if not check_mode:
            c.kv.put(k, v)
        return True
    return False


def kv_put(c, path, data, check_mode):
    changed = False
    for k, v in data.items():
        if k[-5:] == '.json':
            changed |= kv_put_one(c, path + '/' + k[:-5], json.dumps(v), check_mode)
        elif type(v) == dict:
            changed |= kv_put(c, path + '/' + k, v, check_mode)
        else:
            changed |= kv_put_one(c, path + '/' + k[:-5], str(v), check_mode)
    return changed


def main():
    module = AnsibleModule(
        argument_spec=dict(
            token=dict(type='str'),
            token_file=dict(type='str'),
            path=dict(required=True, type='str'),
            data=dict(required=True, type='dict'),
            host=dict(default='localhost', type='str'),
            port=dict(default=8500, type='int')
        ),
        supports_check_mode=True
    )

    token = module.params.get('token')
    token_file = module.params.get('token_file')
    path = module.params.get('path')
    data = module.params.get('data')
    host = module.params.get('host')
    port = module.params.get('port')

    if token_file:
        with open(token_file) as f:
            token = f.read()
    if token is None:
        token = os.getenv('CONSUL_HTTP_TOKEN')
    c = consul.Consul(host=host, port=port, token=token)
    changed = kv_put(c, path, data, module.check_mode)
    module.exit_json(changed=changed)


if __name__ == '__main__':
    main()
