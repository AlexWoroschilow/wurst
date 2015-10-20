#!/bin/sh
set -e
. "$(pwd)/starter-settings.sh";

check_file ${SCRIPT_WORKER};

echo "Run worker: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
echo "Server pid: $!";
exit 0;