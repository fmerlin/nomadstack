import json
import os
import nomad
from ansible.module_utils.basic import AnsibleModule
from nomad.api.exceptions import BaseNomadException


def strip(d):
    if type(d) == dict:
        res = dict()
        for k, v in d.items():
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


def filter(d, fields):
    res = dict()
    for k, v in d.items():
        if v is not None and k not in fields:
            res[k] = strip(v)
    return res


def main():
    module = AnsibleModule(
        argument_spec=dict(
            token=dict(type='str'),
            token_file=dict(type='str'),
            Affinities=dict(type='list', elements='dict', options=dict(
                LTarget=dict(type='str'),
                RTarget=dict(type='str'),
                Operand=dict(type='str'),
                Weight=dict(type='int')
            )),
            AllAtOnce=dict(type='bool'),
            Constraints=dict(type='list', elements='dict', options=dict(
                LTarget=dict(type='str'),
                RTarget=dict(type='str'),
                Operand=dict(type='str')
            )),
            Datacenters=dict(type='list', elements='str'),
            ID=dict(type='str'),
            Meta=dict(type='dict'),
            Name=dict(required=True, type='str'),
            Payload=dict(type='str', options=dict(
                Spec=dict(type='str'),
                Timezone=dict(type='str'),
                SpecType=dict(type='str'),
                Enabled=dict(type='bool'),
                ProhibitOverlap=dict(type='bool')
            )),
            ParametrizedJob=dict(type='str'),
            Periodic=dict(type='dict'),
            Priority=dict(type='int'),
            Region=dict(type='str'),
            ReschedulePolicy=dict(type='dict'),
            Spread=dict(type='list', elements='dict', options=dict(
                Attribute=dict(type='str'),
                Weight=dict(type='int'),
                SpreadTarget=dict(type='list', elements='dict', options=dict(
                    Value=dict(type='str'),
                    Percent=dict(type='int')
                ))
            )),
            TaskGroups=dict(type='list', elements='dict', options=dict(
                Name=dict(required=True, type='str'),
                Count=dict(type='int'),
                Migrate=dict(type='dict', options=dict(
                    HealthCheck=dict(type='str'),
                    HealthDeadline=dict(type='int'),
                    MaxParallel=dict(type='int'),
                    MinHealthyTime=dict(type='int')
                )),
                RestartPolicy=dict(type='dict', options=dict(
                    Interval=dict(type='int'),
                    Attempts=dict(type='int'),
                    Delay=dict(type='int'),
                    Mode=dict(type='str')
                )),
                ReschedulePolicy=dict(type='dict', options=dict(
                    Attempts=dict(type='int'),
                    Delay=dict(type='int'),
                    DelayFunction=dict(type='str'),
                    Interval=dict(type='int'),
                    MaxDelay=dict(type='int'),
                    Unlimited=dict(type='bool')
                )),
                EphemeralDisk=dict(type='dict', options=dict(
                    SizeMB=dict(type='int'),
                    Migrate=dict(type='bool'),
                    Sticky=dict(type='bool')
                )),
                Tasks=dict(type='list', elements='dict', options=dict(
                    Name=dict(required=True, type='str'),
                    Driver=dict(type='str'),
                    Artifacts=dict(type='list', elements='dict', options=dict(
                        GetterSource=dict(type='str'),
                        RelativeDestination=dict(type='str'),
                        GetterOptions=dict(type='dict')
                    )),
                    Config=dict(type='dict', options=dict(
                        image=dict(required=True, type='str'),
                        port_map=dict(type='list'),
                        network_mode=dict(type='str'),
                        volumes=dict(type='list', elements='str'),
                        dns_servers=dict(type='list', elements='str'),
                        dns_search_domains=dict(type='list', elements='str'),
                        dns_options=dict(type='list', elements='str'),
                        extra_hosts=dict(type='list', elements='str'),
                        command=dict(type='str'),
                        args=dict(type='list', elements='str'),
                        cap_add=dict(type='list', elements='str'),
                        cap_drop=dict(type='list', elements='str'),
                        work_dir=dict(type='str'),
                        volume_driver=dict(type='str'),
                        labels=dict(type='dict'),
                        ulimit=dict(type='dict'),
                        sysctl=dict(type='dict'),
                        privileged=dict(type='bool'),
                        shm_size=dict(type='int'),
                        storage_opt=dict(type='dict'),
                        security_opt=dict(type='list', elements='str'),
                        entrypoint=dict(type='list', elements='str'),
                        devices=dict(type='list', elements='dict'),
                        mounts=dict(type='list', elements='dict', options=dict(
                            type=dict(required=True, type='str', choices=['bind', 'tmpfs', 'volume']),
                            target=dict(required=True, type='str'),
                            source=dict(required=True, type='str'),
                            readonly=dict(type='bool'),
                            bind_options=dict(type='dict', options=dict(
                                propagation=dict(type='str')
                            )),
                            volume_options=dict(type='dict', options=dict(
                                name=dict(type='str'),
                                options=dict(type='dict')
                            )),
                            tmpfs_options=dict(type='dict', options=dict(
                                size=dict(type='int')
                            ))
                        )),
                        logging=dict(type='dict', options=dict(
                            type=dict(required=True, type='str'),
                            config=dict(type='list', elements='dict', options={
                                "fluentd-address": dict(type='str'),
                                "fluentd-async-connect": dict(type='bool'),
                                "tag": dict(type='str')
                            })
                        ))
                    )),
                    User=dict(type='str'),
                    Env=dict(type='dict'),
                    Vault=dict(type='dict', options=dict(
                        ChangeMode=dict(type='str'),
                        ChangeSignal=dict(type='str'),
                        Env=dict(type='str'),
                        Policies=dict(type='list', elements='str')
                    )),
                    Templates=dict(type='list', elements='dict', options=dict(
                        SourcePath=dict(type='str'),
                        EmbeddedTmpl=dict(type='str'),
                        ChangeMode=dict(type='str'),
                        ChangeSignal=dict(type='str'),
                        DestPath=dict(type='str'),
                        Envvars=dict(type='bool'),
                        Perms=dict(type='str'),
                        LeftDelim=dict(type='str'),
                        RightDelim=dict(type='str'),
                        Splay=dict(type='int'),
                        VaultGrace=dict(type='int'),
                    )),
                    Services=dict(type='list', elements='dict', options=dict(
                        Name=dict(required=True, type='str'),
                        Tags=dict(type='list', elements='str'),
                        CanaryTags=dict(type='list', elements='str'),
                        Meta=dict(type='dict'),
                        PortLabel=dict(type='str'),
                        AddressMode=dict(type='str', choices=['auto','driver','host']),
                        Checks=dict(type='list', elements='dict', options=dict(
                            Id=dict(type='str'),
                            Name=dict(type='str'),
                            Type=dict(type='str', choices=['script','http','tcp']),
                            Command=dict(type='str'),
                            Args=dict(type='list'),
                            Headers=dict(type='dict'),
                            Method=dict(type='str'),
                            Path=dict(type='str'),
                            Protocol=dict(type='str'),
                            PortLabel=dict(type='str'),
                            Interval=dict(type='int'),
                            Timeout=dict(type='int')
                        )),
                    )),
                    Resources=dict(type='dict', options=dict(
                        CPU=dict(type='int'),
                        MemoryMB=dict(type='int'),
                        Networks=dict(type='list', elements='dict', options=dict(
                            Device=dict(type='str'),
                            CIDR=dict(type='str'),
                            IP=dict(type='str'),
                            MBits=dict(type='int'),
                            ReservedPorts=dict(type='list', elements='dict', options=dict(
                                Label=dict(type='str'),
                                Value=dict(type='int')
                            )),
                            DynamicPorts=dict(type='list', elements='dict', options=dict(
                                Label=dict(type='str')
                            )),
                        )),
                    )),
                    Leader=dict(type='bool'),
                    VolumeMount=dict(type='list', elements='dict', options=dict(
                        Source=dict(type='str'),
                        Destination=dict(type='str'),
                        ReadOnly = dict(type='bool'),
                    ))
                )),
                Volume=dict(type='list', elements='dict', options=dict(
                    Type=dict(type='str', choices=['host']),
                    ReadOnly=dict(type='bool'),
                    Config=dict(type='dict')
                ))
            )),
            Type=dict(type='str'),
            Update=dict(type='dict', options=dict(
                MaxParallel=dict(type='int'),
                MinHealthyTime=dict(type='int'),
                HealthyDeadline=dict(type='int'),
                AutoRever=dict(type='int'),
                Canary=dict(type='int')
            ))
        ),
        supports_check_mode=True
    )

    try:
        name = module.params.get('ID')
        token = module.params.get('token')
        token_file = module.params.get('token_file')
        data = dict(Job=filter(module.params, ['token', 'token_file']))

        if token_file:
            with open(token_file) as f:
                token = f.read()
        if token is None:
            token = os.getenv('NOMAD_TOKEN')
        n = nomad.Nomad(token=token)

        if module.check_mode:
            res = n.validate.validate_job(data).json()
            module.exit_json(changed=False, **res)
        else:
            res = n.job.register_job(name, data)
            module.exit_json(changed=True, **res)
    except BaseNomadException as e:
        module.fail_json(status_code=e.nomad_resp.status_code, msg=e.nomad_resp.text, params=strip(module.params), type=type(e))


if __name__ == '__main__':
    main()
