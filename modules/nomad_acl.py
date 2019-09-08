import json
import os
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
            token=dict(type='str'),
            token_file=dict(type='str'),
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

    token = module.params.get('token')
    token_file = module.params.get('token_file')
    if token_file:
        with open(token_file) as f:
            token = f.read()
    if token is None:
        token = os.getenv('NOMAD_TOKEN')
    n = nomad.Nomad(token=token)

    if module.check_mode:
        module.exit_json(changed=False)
    else:
        n.acl.create_policy(module.params.get('Name'), dict(
            Name=module.params.get('Name'),
            Description=module.params.get('Description', ''),
            Rules=json.dumps(strip(module.params.get('Rules')))
        ))
        module.exit_json(changed=True)


if __name__ == '__main__':
    main()
