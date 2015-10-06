#!/bin/sh

echo_std_err () {
	echo "${@}" 1>&2;
}

folder_exists_or_error () {
	if [ ! -d "$@" ]; then
		echo_std_err "Missed folder: ${@}";
	fi
}


file_exists_or_error () {
	if [ ! -f "$@" ]; then
		echo_std_err "Missed file: ${@}";
	fi
}

# Write a xml file with status
# for php status-rss stream 
write_xml_status () {
	echo "<?xml version=\"1.1\" encoding=\"UTF-8\" ?>" > $1;
	echo "<response>" >> $1;
	echo "<task>wurst-update</task>" >> $1;
	echo "<date>$(date +%s)</date>" >> $1;
	echo "<status>${?}</status>" >> $1;
	echo "<command><![CDATA[<TMPL_VAR NAME=command>]]></command>" >> $1;
	echo "<error><![CDATA[$(cat $2)]]></error>" >> $1;
	echo "<error><![CDATA[$(cat $3)]]></error>" >> $1;
	echo "</response>" >> $1;
	exit;
}