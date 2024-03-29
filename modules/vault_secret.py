import json
import os
import hvac
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            token=dict(type='str'),
            token_file=dict(type='str'),
            path=dict(required=True, type='str'),
            secret=dict(required=True, type='dict')
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
        res = client.secrets.kv.v2.create_or_update_secret(
            path=module.params.get('path'),
            secret=module.params.get('secret')
        )
        module.exit_json(changed=True, **res['data'])
    except Exception as e:
        module.fail_json(msg=e.args[0], path=module.params.get('path'),
            secret=module.params.get('secret'), type=type(e))


if __name__ == '__main__':
    main()
