import json

import nomad
from ansible.module_utils.basic import AnsibleModule


def strip(d):
    if type(d) == dict:
        res = dict()
        for k, v in d.iteritems():
            if v is not None:
                res[k] = strip(v)
        return res
    if type(d) == list:
        res = list()
        for v in d:
            if v is not None:
                res.append(strip(v))
        return res
    return d


def main():
    module = AnsibleModule(
        argument_spec=dict(
            Name=dict(required=True, type='str'),
            Description=dict(type='str'),
            Rules=dict(required=True, type='dict', options=dict(
                namespace=dict(type='dict'),
                agent=dict(type='dict', options=dict(
                    policy=dict(type='str')
                )),
                node=dict(type='dict', options=dict(
                    policy=dict(type='str')
                )),
                quota=dict(type='dict', options=dict(
                    policy=dict(type='str')
                ))
            ))
        )
    )
    data = strip(module.params)

    with open('/etc/nomad.key') as f:
        token = f.read()
        n = nomad.Nomad(token=token)

    if module.check_mode:
        print(json.dumps(data))
        module.exit_json(changed=False)
    else:
        n.acl.create_policy(data.get('Name'), dict(
            Name=data.get('Name'),
            Description=data.get('Description', ''),
            Rules=json.dumps(data.get('Rules'))
        ))
        module.exit_json(changed=True)


if __name__ == '__main__':
    main()
