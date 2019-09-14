import os
import hvac
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            token=dict(type='str'),
            token_file=dict(type='str'),
            name=dict(type='str'),
            capabilities=dict(type='dict')
        ),
        supports_check_mode=True
    )

    try:
        token = module.params.get('token')
        token_file = module.params.get('token_file')
        if token_file:
            with open(token_file) as f:
                token = f.read()
        if token is None:
            token = os.getenv('VAULT_TOKEN')
        if token is None or module.check_mode:
            module.exit_json(changed=False)
        client = hvac.Client(token=token)
        policy = module.params.get('capabilities')
        hcl = '\n'.join(['path "' + k + '" { capabilities = ["' + '","'.join(v) + '"] }' for k, v in policy.items()])

        res = client.sys.create_or_update_policy(
            name=module.params.get('name'),
            policy=hcl
        )
        module.exit_json(changed=True)
    except Exception as e:
        module.fail_json(msg=e.args[0], name=module.params.get('name'),
            capabilities=module.params.get('capabilities'), type=type(e))


if __name__ == '__main__':
    main()