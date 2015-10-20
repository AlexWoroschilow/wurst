#!/bin/sh
set -e
. "$(pwd)/starter-settings.sh";

check_file ${SCRIPT_SERVER};

echo "Run server: ${SCRIPT_SERVER}";
${SCRIPT_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
echo "Server pid: $!";
exit 0;