from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            src=dict(required=True, type='str'),
            type=dict(type='str')
        )
    )
    try:
        src = module.params.get('src')
        type = module.params.get('type')
        with open(src, 'r') as f:
            res = f.read()
        if type == 'json':
            import json
            module.exit_json(changed=False, **json.loads(res))
        elif type == 'yaml':
            import yaml
            module.exit_json(changed=False, **yaml.load(res))
        else:
            module.exit_json(changed=False, data=res)
    except Exception as e:
        module.fail_json(msg=e.args[0])


if __name__ == '__main__':
    main()
