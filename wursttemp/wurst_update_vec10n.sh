#!/bin/sh
set -e
#$ -clear
#$ -S /bin/bash
#$ -w e
##$ -cwd
#$ -m e -M margraf@zbh.uni-hamburg.de
#$ -j y
#$ -q 32c.q
#$ -pe mpi_pe 8 
##$ -pe mpi 4-128 

BOOTSTRAP="$(pwd)/lib/bootstrap.sh";
SETTINGS="/opt/SGE6.2u5p2/zbh/common/settings.sh";

SRC=$(pwd);
FILE_STD_SRC="${SRC}/output";
FILE_STD_ERR="${FILE_STD_SRC}/wurst_update_vec10n_err.log";
FILE_STD_OUT="${FILE_STD_SRC}/wurst_update_vec10n_out.log";
FILE_STD_XML="${FILE_STD_SRC}/wurst_update_vec10n_xml.xml";

FOLDER_SGE="${SGE_O_HOME}";
FOLDER_TEMP="${TMPDIR}";
FOLDER_TEMP_MACHINES="${FOLDER_TEMP}/machines";

BIN_MPD_EXEC="/home/margraf/lib/mpi/bin/mpiexec";
BIN_MPD_TRACE="/home/margraf/lib/mpi/bin/mpdtrace";
BIN_MPD_BOOT="/home/margraf/lib/mpi/bin/mpdboot";
BIN_MPD_EXIT="/home/margraf/lib/mpi/bin/mpdallexit";

# Include bootstrap shell script 
# with some helpful functions and settings
# for bin files like qsub and other
. ${BOOTSTRAP}
# Import shell with cluster settings
# needs to get some specified binary files
# like qsub and so one
. ${SETTINGS};

echo "Check folder: ${FILE_STD_SRC}";
mkdir -p ${FILE_STD_SRC};
echo "Switch std_err to: ${FILE_STD_ERR}";
exec 2> ${FILE_STD_ERR};
echo "Switch std_out to: ${FILE_STD_OUT}";
exec 1> ${FILE_STD_OUT};


# Catch sytem signals needs to write 
# a xml files for rss status stream
trap "write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};" EXIT
trap "write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};" QUIT
trap "write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};" KILL
trap "write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};" HUP
trap "write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};" INT

# record starting time and 
# machine the script was executed
date
uname -a

check_variable "JOB_NAME" ${JOB_NAME};
check_variable "FOLDER_SGE" ${FOLDER_SGE};
check_variable "FOLDER_TEMP" ${FOLDER_TEMP};
check_variable "PE_HOSTFILE" ${PE_HOSTFILE};

check_folder "${FOLDER_SGE}";
check_folder "${FOLDER_TEMP}";
check_folder "${FOLDER_TEMP_MACHINES}";

check_file "${BIN_MPD_EXEC}";
check_file "${BIN_MPD_TRACE}";
check_file "${BIN_MPD_BOOT}";
check_file "${BIN_MPD_EXIT}";

RUN_ID=$( get_run_id "${SGE_O_HOME}" "${JOB_NAME}" "$0" );
echo "Run id is: ${RUN_ID}";

#echo "----------------- $PE_HOSTFILE:-----------------------"
#cat $PE_HOSTFILE
#echo "-----------------------------------------------------"


#echo "----------------------MACHINES-----------------------"
#awk '{print $1":"$2}' $PE_HOSTFILE > $TMPDIR/mpi.hosts
#cat $TMPDIR/mpi.hosts #machines
#hostno=`cat $TMPDIR/mpi.hosts | wc -l`
#echo "----------------------MPDBOOT------------------------"
#sleep 2
#/home/margraf/lib/mpi/bin/mpdboot --totalnum=$NSLOTS -d -n $hostno -f $TMPDIR/mpi.hosts --verbose

##/home/margraf/bin32/bin/mpdboot -n 3 --rsh=/usr/bin/ssh -f $TMPDIR/machines --verbose
#echo "Using $hostno nodes with $NSLOTS slots"

#echo "------------mpdtrace-------------------"
##/home/margraf/bin32/bin/mpdtrace
##/home/margraf/lib/mpi/bin/mpdtrace
#echo "--------------mpiexec------------------"
##/home/margraf/lib/mpi/bin/mpiexec -n $NSLOTS perl ../perlscripts/mk_pvecs_mpi.pl -l /projects/bm/pdb_all.list 
##/home/margraf/lib/mpi/bin/mpiexec.hydra -f $TMPDIR/mpi.hosts -n $NSLOTS perl ../perlscripts/mk_pvecs_mpi.pl -l /projects/bm/pdb90.list 
#time /home/margraf/lib/mpi/bin/mpiexec -n $NSLOTS perl /home/margraf/andrew/scripts/perlscripts/mk_pvecs_mpi.pl -l /smallfiles/public/no_backup/bm/pdb_all.list 
#perl_ret=$?
#echo "--------------mpdallexit------------------"
##/home/margraf/bin32/bin/mpdallexit
#/home/margraf/lib/mpi/bin/mpdallexit

#echo return code $perl_ret from perl script at
#date

#exit $perl_ret
exit;