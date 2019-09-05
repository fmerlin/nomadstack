import nomad
import os
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
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
                Name=dict(type='str'),
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
                    Name=dict(type='str'),
                    Driver=dict(type='str'),
                    Artifacts=dict(type='list', elements='dict', options=dict(
                        GetterSource=dict(type='str'),
                        RelativeDestination=dict(type='str'),
                        GetterOptions=dict(type='dict')
                    )),
                    Config=dict(type='dict', options=dict(
                        image=dict(type='str'),
                        port_map=dict(type='list'),
                        network_mode=dict(type='str'),
                        volumes=dict(type='list', elements='str'),
                        dns_servers=dict(type='list', elements='str'),
                        command=dict(type='str'),
                        work_dir=dict(type='str'),
                        volume_driver=dict(type='str'),
                        devices=dict(type='list', elements='dict'),
                        mounts=dict(type='list', elements='dict'),
                        args=dict(type='list', elements='str'),
                        logging=dict(type='dict', options=dict(
                            type=dict(type='str'),
                            config=dict(type='dict', options={
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
                        Id=dict(type='str'),
                        Name=dict(type='str'),
                        Tags=dict(type='list', elements='str'),
                        PortLabel=dict(type='str'),
                        AddressMode=dict(type='str'),
                        Checks=dict(type='list', elements='dict', options=dict(
                            Id=dict(type='str'),
                            Name=dict(type='str'),
                            Type=dict(type='str'),
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
                            DynamicPorts=dict(type='list', elements='dict', options=dict(
                                Label=dict(type='str'),
                                Value=dict(type='int')
                            )),
                        )),
                    )),
                    Leader=dict(type='bool')
                )),
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

    with open('/etc/nomad.key') as f:
        token = f.read()
        n = nomad.Nomad(token=token)

    if module.check_mode:
        n.validate.validate_job(module.params)
        module.exit_json(changed=False)

    res = n.job.register_job(module.params)
    module.exit_json(changed=True, **res)


if __name__ == '__main__':
    main()
