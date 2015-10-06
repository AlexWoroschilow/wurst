#$ -clear
#$ -S /bin/sh
#$ -w e
##$ -cwd
#$ -m e -M margraf@zbh.uni-hamburg.de
#$ -j y
##$ -q 4core.q@node106,4core.q@node107,4core.q@node108,4core.q@node109
#$ -q 4c.q 
#$ -p -500
#$ -pe mpi_pe 2-28 


if [ -n "$SGE_O_HOME" ] ; then
    run_id=`echo $JOB_NAME | tr -d '[:alpha:]' | tr -d '[:punct:]'`
else
    run_id=`echo $0 | tr -d '[:alpha:]' | tr -d '[:punct:]'`
fi

exec 1> ~/4core_wurst.out
exec 2> ~/4core_wurst.err
echo run_id is $run_id
date
uname -a

#export DISPLAY='0:0'

echo "-----------------$PE_HOSTFILE:-----------------------"
cat $PE_HOSTFILE
echo "-----------------------------------------------------"

echo "----------------------MACHINES-----------------------"
awk '{print $1":"$2}' $PE_HOSTFILE > $TMPDIR/mpi.hosts
cat $TMPDIR/mpi.hosts #machines
hostno=`cat $TMPDIR/mpi.hosts | wc -l`
echo "----------------------MPDBOOT------------------------"
sleep 2
/home/margraf/lib/mpi/bin/mpdboot -d -n $hostno -f $TMPDIR/mpi.hosts --verbose

#/home/margraf/bin32/bin/mpdboot -n 3 --rsh=/usr/bin/ssh -f $TMPDIR/machines --verbose
#sleep 10
echo "Using $hostno nodes with $NSLOTS slots"

echo "------------mpdtrace-------------------"
#/home/margraf/bin32/bin/mpdtrace
/home/margraf/lib/mpi/bin/mpdtrace
echo "--------------mpiexec------------------"
#/home/margraf/bin32/bin/mpiexec -n $NSLOTS hostname
/home/margraf/lib/mpi/bin/mpiexec -n $NSLOTS hostname
#mpiexec.py -n $NSLOTS perl ../perlscripts/salamimpi.pl -l /projects/bm/pdb90.list -q ../modeldir/1CVU.pdb
perl_ret=$?
echo "--------------mpdallexit------------------"
#/home/margraf/bin32/bin/mpdallexit
/home/margraf/lib/mpi/bin/mpdallexit

echo return code $perl_ret from perl script at
date

exit $perl_ret
