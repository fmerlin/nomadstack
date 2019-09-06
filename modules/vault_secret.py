import hvac
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            path=dict(type='str'),
            secret=dict(type='dict')
        )
    )

    with open('/etc/vault.key') as f:
        token = f.read()
        client = hvac.Client(token=token)

    client.secrets.kv.v2.create_or_update_secret(
        path=module.params.get('path'),
        secret=module.params.get('secret'),
    )


if __name__ == '__main__':
    main()
