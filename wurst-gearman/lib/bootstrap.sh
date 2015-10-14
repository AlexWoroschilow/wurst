#!/bin/sh

get_run_id () {
			
	if [ -n "${1}" ] ; then
		RETURN=`echo ${2} | tr -d '[:alpha:]' | tr -d '[:punct:]'`
	else
	    RETURN=`echo ${3} | tr -d '[:alpha:]' | tr -d '[:punct:]'`
	fi
	echo ${RETURN};
}

# Write a xml file with status
# for php status-rss stream 
write_xml_status () {

	echo "<?xml version=\"1.1\" encoding=\"UTF-8\" ?>" > $1;
	echo "<response>" >> $1;
	echo "<task>wurst-update</task>" >> $1;
	echo "<date>$(date +%s)</date>" >> $1;
	echo "<status>${?}</status>" >> $1;
	echo "<log><![CDATA[$(cat $2)]]></log>" >> $1;
	echo "<error><![CDATA[$(cat $3)]]></error>" >> $1;
	echo "</response>" >> $1;
	
	#	kill 0;
	
	exit;
}

echo_std_err () {
	echo "${@}" 1>&2;
}

# Check is variable is empty 
# write to std error
check_variable () {
	if [ ! -n "${2}" ];then
		echo_std_err "Empty variable: ${1}";
	fi	
}

check_folder () {
	if [ ! -d "$@" ]; then
		echo_std_err "Missed folder: ${@}";
	fi
}


check_file () {
	if [ ! -f "$@" ]; then
		echo_std_err "Missed file: ${@}";
	fi
}
