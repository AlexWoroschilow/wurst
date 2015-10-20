#!/bin/sh
set -e
. "$(pwd)/starter-settings.sh";

check_file ${SCRIPT_PLANNER};

DEST="${SCRIPT_STD_XML}";
ERROR="${SCRIPT_STD_ERR}";
FATAL="${SCRIPT_STD_FAT}";
NOTICE="${SCRIPT_STD_NOT}";
INFO="${SCRIPT_STD_LOG}";


PLANNER_PID=0;

# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'write_xml_status ${PLANNER_PID} ${DEST} ${INFO} ${NOTICE} ${ERROR} ${FATAL};' EXIT KILL HUP INT TERM

echo "Run planner: ${SCRIPT_PLANNER}";
${SCRIPT_PLANNER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
PLANNER_PID=$!;

# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'xml ${PLANNER_PID} ${DEST} ${INFO} ${NOTICE} ${ERROR} ${FATAL};' EXIT KILL HUP INT TERM

echo "Waiting for pid: ${PLANNER_PID}";
wait ${PLANNER_PID};
exit;