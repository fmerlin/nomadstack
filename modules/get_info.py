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
            changed |= kv_put_one(c, path + '/' + k, str(v), check_mode)
    return changed


def main():
    module = AnsibleModule(
        argument_spec=dict(),
        supports_check_mode=True
    )
    module.exit_json(changed=False, hostname=os.get)


if __name__ == '__main__':
    main()
