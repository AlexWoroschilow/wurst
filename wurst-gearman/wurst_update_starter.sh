#!/bin/sh
set -e
. "$(pwd)/lib/bootstrap.sh";

SCRIPT_WORKER="$(pwd)/gearman/worker.pl";
SCRIPT_CLIENT="$(pwd)/gearman/client.pl"
SCRIPT_SERVER="$(pwd)/gearman/server.pl";
SCRIPT_SERVER_HOST=$(hostname --long);



FILE_STD_SRC="$(pwd)/output";
FILE_STD_ERR="${FILE_STD_SRC}/wurst_update_starter_err.log";
FILE_STD_OUT="${FILE_STD_SRC}/wurst_update_starter_out.log";
FILE_STD_XML="${FILE_STD_SRC}/wurst_update_starter_xml.xml";

FILE_PDB_LIB="/smallfiles/public/no_backup/bm/pdb_lib.list";
FILE_PDB_ALL="/smallfiles/public/no_backup/bm/pdb_all.list";
FILE_PDB_SLM="/smallfiles/public/no_backup/bm/pdb_slm.list";
FILE_PDB_90N="/smallfiles/public/no_backup/bm/pdb_90n.list";


echo "Check folder: ${FILE_STD_SRC}";
mkdir -p ${FILE_STD_SRC};
echo "Switch std_err to: ${FILE_STD_ERR}";
exec 2> ${FILE_STD_ERR};
echo "Switch std_out to: ${FILE_STD_OUT}";
exec 1> ${FILE_STD_OUT};


# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};' EXIT
trap 'write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};' QUIT
trap 'write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};' KILL
trap 'write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};' HUP
trap 'write_xml_status ${FILE_STD_XML} ${FILE_STD_OUT} ${FILE_STD_ERR};' INT


check_file ${SCRIPT_SERVER};
check_file ${SCRIPT_WORKER};
check_file ${SCRIPT_CLIENT};

check_file ${FILE_PDB_LIB};
check_file ${FILE_PDB_ALL};
check_file ${FILE_PDB_SLM};
check_file ${FILE_PDB_90N};

echo "Run server: ${SCRIPT_SERVER}";
${SCRIPT_SERVER} 1>>${FILE_STD_OUT} 2>> ${FILE_STD_ERR} &
SERVER_PID=$!
echo "Server pid: ${SERVER_PID}"


echo "Run: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --server=${SCRIPT_SERVER_HOST} 1>>${FILE_STD_OUT} 2>> ${FILE_STD_ERR} &
echo "Run: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --server=${SCRIPT_SERVER_HOST} 1>>${FILE_STD_OUT} 2>> ${FILE_STD_ERR} &
echo "Run: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --server=${SCRIPT_SERVER_HOST} 1>>${FILE_STD_OUT} 2>> ${FILE_STD_ERR} &
echo "Run: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --server=${SCRIPT_SERVER_HOST} 1>>${FILE_STD_OUT} 2>> ${FILE_STD_ERR} &


echo "Run client: ${SCRIPT_CLIENT}";
${SCRIPT_CLIENT} --server=${SCRIPT_SERVER_HOST} 1>>${FILE_STD_OUT} 2>> ${FILE_STD_ERR} &
CLIENT_PID=$!
echo "Client pid: ${CLIENT_PID}"

echo "Waiting for pid: ${CLIENT_PID}"
wait ${CLIENT_PID};
exit 0;
