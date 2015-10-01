#!/bin/bash
echo "start synchronisation of pdbredo:"

PDBREDODIR=/smallfiles/public/no_backup/pdbredo

echo "source: rsync://rsync.cmbi.ru.nl/pdb_redo/"
echo "target: $PDBREDODIR/"
echo "Please choose a letter what to download ..."
echo "a - download the whole pdb_redo structure"
echo "b - download only optimised pdb files"
read -n 1 choice
echo
echo "choice is : $choice"

d=86400 # day  in sec.
h=3600  # hour in sec.
m=60    # min  in sec.
s=0     # secs.

if [ "$1" != "" ]; then
   echo "please wait ... "
   COUNT=$1
	printf "countdown (h-m-s):        %d - %d - %d"  $(( COUNT / h )) $(( (COUNT % h) / m)) $(( COUNT % m  )) 
	
	for (( ; $COUNT >= 10 ; COUNT=$(( COUNT - 10 )) )); do
		printf "\b\b\b\b\b"
		if [ $(( COUNT / h )) > 9 ]; then printf "\b\b"; else printf "\b"; fi
		if [ $(( (COUNT % h) / m )) > 9 ]; then printf "\b\b"; else printf "\b"; fi
		if [ $(( COUNT % m )) > 9 ]; then 
		   printf "\b\b" 
			printf "%d - %d - %d"  $(( COUNT / h )) $(( (COUNT % h) / m )) $(( COUNT % m )) 
      else
		   printf "\b"
		   printf "%d - %d - %d"  $(( COUNT / h )) $(( (COUNT % h) / m )) $(( COUNT % m ))
		fi
	   sleep 10
	done
   echo ""
fi

printf "starting now ..."

if [ -e /smallfiles/public/no_backup/pdbredo/ ]; then
   if [ "$choice" == "a" ]; then	
   	rsync -uaz --delete rsync://rsync.cmbi.ru.nl/pdb_redo/ /smallfiles/public/no_backup/pdbredo/
	fi
   
	if [ "$choice" == "b" ]; then
	  rsync -avW --delete --filter '+ **/' --filter '+ *.pdb' --filter '- *' --prune-empty-dirs rsync://rsync.cmbi.ru.nl/pdb_redo/ /smallfiles/public/no_backup/pdbredo/
	fi

	echo "finished at "`date`
else
	echo "Sorry, but target folder does not exist. Check target folder and start again. ByeBye and Good Luck!"
fi
