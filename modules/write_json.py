import json
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            dest=dict(required=True, type='path'),
            data=dict(required=True, type='dict')
        )
    )
    try:
        src = module.params.get('src')
        data = module.params.get('data')
        with open(src, 'w') as f:
            json.dump(data, f)
        module.exit_json(changed=True)
    except Exception as e:
        module.fail_json(msg=e.args[0])


if __name__ == '__main__':
    main()
