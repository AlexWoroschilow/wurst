#!/bin/sh
#$ -clear
#$ -S /bin/sh
#$ -w e
#$ -m e -M margraf@zbh.uni-hamburg.de
#$ -j y
#$ -q 32c.q

SRC=$(pwd);

SETTINGS="/opt/SGE6.2u5p2/zbh/common/settings.csh";
BOOTSTRAP="${SRC}/lib/bootstrap.sh";

FILE_STD_SRC="${SRC}/output";
FILE_STD_ERR="${FILE_STD_SRC}/wurst_update_err.log";
FILE_STD_OUT="${FILE_STD_SRC}/wurst_update_out.log";
FILE_STD_XML="${FILE_STD_SRC}/wurst_update_xml.xml";

FILE_PDB_LIB="/smallfiles/public/no_backup/bm/pdb_lib.list";
FILE_PDB_ALL="/smallfiles/public/no_backup/bm/pdb_all.list";
FILE_PDB_SLM="/smallfiles/public/no_backup/bm/pdb_slm.list";
FILE_PDB_90N="/smallfiles/public/no_backup/bm/pdb_90n.list";


SCRIPT_PDB_TO_BIN="${SRC}/pdb_set_to_bin.pl";
SCRIPT_PDB_TO_BIN_ALL="${SCRIPT_PDB_TO_BIN} -a";
SCRIPT_PDB_TO_VEC="${SRC}/mkvecs10n.sh";

# Include bootstrap shell script 
# with some helpful functions and settings
# for bin files like qsub and other
. ${BOOTSTRAP}

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

file_exists_or_error ${SETTINGS};
# Import shell with cluster settings
# needs to get some specified binary files
# like qsub and so one 
. ${SETTINGS};

file_exists_or_error ${FILE_PDB_LIB};
file_exists_or_error ${FILE_PDB_ALL};
file_exists_or_error ${FILE_PDB_SLM};
file_exists_or_error ${FILE_PDB_90N};

file_exists_or_error ${SCRIPT_PDB_TO_BIN};
file_exists_or_error ${SCRIPT_PDB_TO_VEC};

# Do out on error if all 
# files have been checked
# needs to see all path errors 
set -e

echo "Run: ${SCRIPT_PDB_TO_BIN_ALL}";
perl ${SCRIPT_PDB_TO_BIN_ALL};
echo "Create: ${FILE_PDB_ALL} from ${FILE_PDB_LIB}";
cp ${FILE_PDB_LIB} ${FILE_PDB_ALL};

echo "Run: ${SCRIPT_PDB_TO_BIN}";
perl ${SCRIPT_PDB_TO_BIN}

echo "Create: ${FILE_PDB_90N} from ${FILE_PDB_LIB}";
cp ${FILE_PDB_LIB} ${FILE_PDB_90N};

echo "Create: ${FILE_PDB_SLM} from ${FILE_PDB_LIB}";
cp ${FILE_PDB_LIB} ${FILE_PDB_SLM};


# calculate all the 
# probability vectors in parallel.
echo "Run: ${SCRIPT_PDB_TO_VEC}";
qsub ${SCRIPT_PDB_TO_VEC}

# record the time we finished
date

exit 
