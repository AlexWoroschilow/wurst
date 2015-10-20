#!/bin/sh
set -e
. "$(pwd)/starter-settings.sh";

STARTER_WORKER="$(pwd)/starter-worker.sh";
STARTER_PLANNER="$(pwd)/starter-planner.sh"
STARTER_SERVER="$(pwd)/starter-server.sh";

check_file ${STARTER_WORKER};
check_file ${STARTER_PLANNER};
check_file ${STARTER_SERVER};

echo "Run server: ${STARTER_SERVER}";
${STARTER_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
SERVER_PID=$!
echo "Server pid: ${SERVER_PID}"

sleep 1;

echo "Run: ${STARTER_PLANNER}";
${STARTER_PLANNER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
CLIENT_PID=$!

sleep 3;

echo "Run: ${STARTER_WORKER}";
${STARTER_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &