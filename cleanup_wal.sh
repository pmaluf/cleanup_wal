#!/bin/bash
#
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
#
# Alteracoes:
#
# Data       Autor               Descricao
# ---------- ------------------- ----------------------------------------------------
#
#====================================================================================

# Variaveis globais
THRESHOLD=80
PURGE=70
BKP_COUNT=1
PGCLEANUP=`which pg_archivecleanup`
STATUS=0
MAIL_LST="user@mydomain"
SCRIPT_DIR=`pwd`
SCRIPT_NAME=`basename $1 | sed -e 's/\.sh$//'`
SCRIPT_LOGDIR="${SCRIPT_DIR}/logs"
LOG_FILE="${SCRIPT_LOGDIR}/cleanup_wal.log"

# Funcoes
help()
{
  head -17 $0 | tail -16
  exit
}

check_space()
{
  TOTAL_MB=`df ${PGARCH} -Pm | tail -1 | awk '{ print $2 }'`
  USED_MB=`df ${PGARCH} -Pm | tail -1 | awk '{ print $3 }'`
  USED_PCT=`expr 100 \* ${USED_MB} \/ ${TOTAL_MB}`
  CRITICAL_PCT=`expr 100 \- \( 100 \- ${THRESHOLD} \) \/ 3`
  PURGE_MB=`expr ${USED_MB} - ${PURGE} \* ${TOTAL_MB} \/ 100`
  if [ ! $1 ]; then
    echo "PG_ARCHIVE: ${PGARCH}"
    echo "TOTAL_MB = ${TOTAL_MB}" | tee -a ${LOG_FILE}
    echo "USED_MB  = ${USED_MB}"  | tee -a ${LOG_FILE}
    echo "USED_PCT = ${USED_PCT}" | tee -a ${LOG_FILE}
    echo "CRITICAL_PCT = ${CRITICAL_PCT}" | tee -a ${LOG_FILE}
  fi
}

cleanup(){
  if [ "${1}." == "CRITICAL." ] ; then
    for i in `purge_list` ; do
     if [ -f ${PGARCH}/${i} ] ; then
       rm -f "${PGARCH}/${i}" ; STATUS=$?
       sync
     fi
    done
  else
    BKP=`ls -1cart ${PGARCH} | egrep '^*\.backup$'|wc -l`
    for i in `ls -1cart ${PGARCH} | egrep '^*\.backup$'` ; do
      if [ -f ${PGARCH}/${i} ]; then
        ${PGCLEANUP} -d ${PGARCH} ${i}
        rm -f "${PGARCH}/${i}" ; STATUS=$?
        sync
        check_space 1
        [ ${USED_MB} -lt ${THRESHOLD} ] && break
      fi
    done
    if [ "${BKP}." == "0." ]; then
      STATUS="2"
    fi
  fi
  return ${STATUS}
}

purge_list(){
  if [ ${PURGE_MB} -gt 0 ] ; then
    echo "PURGE MB: ${PURGE_MB}"
    ls -lcart ${PGARCH} | egrep "[0-9A-F]{24}$" | awk '{print $5" "$9}' |
    ( while read l; do
        SIZE=`echo $l | cut -d" " -f1`
        NAME=`echo $l | cut -d" " -f2`
        SIZE=`expr ${SIZE} \/ 1024 \/ 1024`
        if [ $PURGE_MB -gt 0 ] ; then
          echo ${NAME}
          PURGE_MB=`expr ${PURGE_MB} \- ${SIZE}`
        fi
      done )
  fi
}

# Tratamento dos Parametros
for arg
do
    delim=""
    case "$arg" in
    #translate --gnu-long-options to -g (short options)
      --threshold)    args="${args}-t ";;
      --purge)        args="${args}-p ";;
      --backup-count) args="${args}-b ";;
      --help)         args="${args}-h ";;
      #pass through anything else
      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
         args="${args}${delim}${arg}${delim} ";;
    esac
done

eval set -- $args

while getopts ":hb:t:p:" PARAMETRO
do
    case $PARAMETRO in
        h) help;;
        t) THRESHOLD=${OPTARG[@]};;
        p) PURGE=${OPTARG[@]};;
        b) BKP_COUNT=${OPTARG[@]};;
        :) echo "Option -$OPTARG requires an argument."; exit 1;;
        *) echo $OPTARG is an unrecognized option ; echo $USAGE; exit 1;;
    esac
done

[ $1 ] || { help ; } 

[ -f ${LOG_FILE} ] && :> ${LOG_FILE} || touch ${LOG_FILE}
[ -d ${PGARCH} ] || { echo "Diretorio $PGARCH nao existe." ; exit 1; }

check_space

if [ ${USED_PCT} -ge ${THRESHOLD} ] ; then
  if [ ${USED_PCT} -ge ${CRITICAL_PCT} ] ; then
    echo "Utilizacao ultrapassa limite critico de ${CRITICAL_PCT}%. Ignorando backups!" | tee -a ${LOG_FILE}
    cleanup CRITICAL
  else
     echo "Iniciando purga dos archives..." | tee -a ${LOG_FILE}
     cleanup
  fi
  if [ "${STATUS}." == "0." ]; then
    STATUS="O"
    MSG="Purga executada com sucesso!"
  elif [ "${STATUS}." == "W." ]; then
    STATUS="W"
    MSG="Nao ha backup do Write-Ahead Logging. Ignorando purga..."
  else
    STATUS="E"
    MSG="Falha ao executar a Purga"
  fi
else
  MSG="Purga nao necessaria."
  STATUS="O"
fi

echo "STATUS: ${STATUS} - MSG: ${MSG}" | tee -a ${LOG_FILE}

if [ "${STATUS}" != "O" ] ; then
  mailx -s "[POSTGRESQL][CLEANUP WAL] ${HOSTNAME} - STATUS: ${STATUS} - MSG: ${MSG}" ${MAIL_LST} < ${LOG_FILE}
fi
