[winclient]
%{ for host, ip in hosts ~}
${host} ansible_host=${ip}
%{ endfor ~}

[winclient:vars]
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_user=<LOCAL_VM_USERNAME>
ansible_password=<LOCAL_VM_PASSWORD>
domain_admin_user=<DOMAIN_ADMIN_USERNAME>
domain_admin_password=<DOMAIN_ADMIN_PASSWORD>
domain_name=<DOMAIN_NAME>
domain_ou_path=<DOMAIN_OU_PATH>
registration_token=<REGISTRATION_TOKEN>