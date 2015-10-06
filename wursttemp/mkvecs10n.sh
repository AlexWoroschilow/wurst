#$ -clear
#$ -S /bin/bash
#$ -w e
##$ -cwd
#$ -m e -M margraf@zbh.uni-hamburg.de
#$ -j y
#$ -q 32c.q
#$ -pe mpi_pe 8 
##$ -pe mpi 4-128 


if [ -n "$SGE_O_HOME" ] ; then
    run_id=`echo $JOB_NAME | tr -d '[:alpha:]' | tr -d '[:punct:]'`
else
    run_id=`echo $0 | tr -d '[:alpha:]' | tr -d '[:punct:]'`
fi

exec 1> /home/other/wurst/output/MPI__vec.out
exec 2> /home/other/wurst/output/MPI__vec.err
echo run_id is $run_id
date
uname -a

echo "-----------------$PE_HOSTFILE:-----------------------"
cat $PE_HOSTFILE
echo "-----------------------------------------------------"

echo "----------------------MACHINES-----------------------"
awk '{print $1":"$2}' $PE_HOSTFILE > $TMPDIR/mpi.hosts
cat $TMPDIR/mpi.hosts #machines
hostno=`cat $TMPDIR/mpi.hosts | wc -l`
echo "----------------------MPDBOOT------------------------"
sleep 2
/home/margraf/lib/mpi/bin/mpdboot --totalnum=$NSLOTS -d -n $hostno -f $TMPDIR/mpi.hosts --verbose

#/home/margraf/bin32/bin/mpdboot -n 3 --rsh=/usr/bin/ssh -f $TMPDIR/machines --verbose
echo "Using $hostno nodes with $NSLOTS slots"

echo "------------mpdtrace-------------------"
#/home/margraf/bin32/bin/mpdtrace
#/home/margraf/lib/mpi/bin/mpdtrace
echo "--------------mpiexec------------------"
#/home/margraf/lib/mpi/bin/mpiexec -n $NSLOTS perl ../perlscripts/mk_pvecs_mpi.pl -l /projects/bm/pdb_all.list 
#/home/margraf/lib/mpi/bin/mpiexec.hydra -f $TMPDIR/mpi.hosts -n $NSLOTS perl ../perlscripts/mk_pvecs_mpi.pl -l /projects/bm/pdb90.list 
time /home/margraf/lib/mpi/bin/mpiexec -n $NSLOTS perl /home/margraf/andrew/scripts/perlscripts/mk_pvecs_mpi.pl -l /smallfiles/public/no_backup/bm/pdb_all.list 
perl_ret=$?
echo "--------------mpdallexit------------------"
#/home/margraf/bin32/bin/mpdallexit
/home/margraf/lib/mpi/bin/mpdallexit

echo return code $perl_ret from perl script at
date

exit $perl_ret
