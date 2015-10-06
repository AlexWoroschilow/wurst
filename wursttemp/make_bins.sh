#$ -clear
#$ -S /bin/sh
#$ -w e
##$ -cwd
#$ -m e -M margraf@zbh.uni-hamburg.de
#$ -j y
#$ -q 4c.q

exec 1> /home/other/wurst/output/mk_bins_o
exec 2> /home/other/wurst/output/mk_bins_e
date
uname -a

perl /home/margraf/andrew/scripts/perlscripts/pdb_set_to_bin.pl -a

date

exit $perl_ret
