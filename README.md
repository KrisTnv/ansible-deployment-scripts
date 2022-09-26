# Slurm workshop cluster

License [![LICENSE](https://img.shields.io/github/license/KrisTnv/sem.svg?style=flat-square)](https://github.com/KrisTnv/sem/blob/master/LICENSE)

1) SSH to acf-login
 
2) SSH to stitchy-dell-1 (Password in Bitwarden)
   SSH root@172.24.12.134

3) SSH to the slurm controller as hpcsys user. 
   SSH hpcsys@192.168.100.152

4) Always run slurm role with "--skip-tags munge" flag and only first time with  "--check --diff" flag.
ansible-playbook cluster.yml --tags slurm --skip-tags munge -K -i ../inventory/hosts.ini --check --diff
