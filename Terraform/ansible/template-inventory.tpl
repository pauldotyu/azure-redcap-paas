[winclient]
%{ for host, ip in hosts ~}
${host} ansible_host=${ip}
%{ endfor ~}

[winclient:vars]
ansible_user=${user}
ansible_password=${password}