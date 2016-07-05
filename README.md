# cleanup_wal.sh

Script to purge the Write-Ahead Logging(wal) on PostgreSQL

## Notice

This script was tested in:

* Linux
  * OS Distribution: CentOS release 6.5 (Final)
  * PostgreSQL: 9.3

## How to use it

```
# cleanup_wal.sh - Script para purga do Write-Ahead Logging(wal) para bancos PostgreSQL
# Criacao: Paulo Victor Maluf - 31/05/2013
#
# Este script verifica a necessidade de remocao de Write-Ahead Logging(wal) antigos, para liberacao
# de espaco em filesystem.
#
# Parametros:
#
#   cleanup_wal.sh -t <THRESHOLD> -p <PURGE>
#
#   -t --threshold    - % de ocupaacao que dispara a purga                 opcional - default 80
#   -p --purge        - % de ocupacao a ser atingido apos a purga          opcional - default 70
#   -h --help         - Mostra este help
#   -b --backup-count - Qtde. minima de backups antes de apagar o archive  opcional - default 1
#
#   Ex.: cleanup_wal.sh -t 90 -p 65 -b 2
```

Example:
```
./cleanup_wal.sh --threshold 90 --purge 65 --backup-count 2
```

## License

This project is licensed under the MIT License - see the [License.md](License.md) file for details
