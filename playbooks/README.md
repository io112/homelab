
## bashrc configuration
1. copy hc.env to ~
2. put aliases to bashrc
```
alias ohc='op run --env-file=${HOME_DIR}/hc.env --'
```
## running with vault

 ansible-playbook -i inventory.yaml maria-backup/backup.yaml