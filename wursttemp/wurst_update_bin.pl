#!/usr/bin/perl
#$ -S /usr/bin/perl
#$ -cwd
#$ -j y
# 7 June 2004
# rcsid = $Id: pdb_set_to_bin.pl,v 1.1.2.4 2007/08/22 21:04:00 torda Exp $

# This will read up the list of clusters given by the protein data bank
# and attempt to write a .bin file for everyone.
# It will write a list of one protein from each cluster.

=pod

=head1 NAME

pdb_set_bin.pl

=head1 DESCRIPTION

Create a .bin files based on a pdb90 list.  By default, try to
create one file per cluster and stop looking at each cluster
after one is written successfully. Create a separate list of
successful representatives.

=head1 OPTIONS

=over

=item B<-a>

Write all .bin files. Without this, we only write the first .bin
file from every cluster.

=item B<-v>

Be more verbose. With every B<-v>, we are more verbose.

=back

=cut

use strict;
use warnings;

use FindBin;
use lib "/home/other/wurst/salamiServer/v02";
use Salamisrvini;
use lib $LIB_LIB;     #initialize in local Salamisrvini.pm;
use lib $LIB_ARCH;    #initialize in local Salamisrvini.pm;

use Wurst;

use POSIX qw(EXIT_SUCCESS EXIT_FAILURE);

# ----------------------- Constants    ------------------------------
use vars qw ( $INPUT_CLST_LIST $OUTPUT_BIN_DIR $PDB_TOP_DIR
  $OUTPUT_LIB_LIST);

# Do not bother writing a file if it is has fewer residues than this.
use vars qw ($MIN_MODEL_SIZE);
$MIN_MODEL_SIZE = 40;

# output file names
use vars qw ( $CLST_BUST $PDB_BUST);
$CLST_BUST = 'cluster_bust';
$PDB_BUST  = 'pdb_file_bust';

# external programs
use vars qw ( @GUNZIP);
@GUNZIP = ( '/usr/bin/gunzip', '-f' );

# ----------------------- Globals      ------------------------------
my $verbosity;

# ----------------------- usage        ------------------------------
sub usage () {
	warn "usage: $0 [-av]\n";
}

# ----------------------- read_cluster_file -------------------------
sub read_cluster_file ($ $ $ \@ \@) {
	my ( $infile, $first, $last, $clust_acq, $clust_chain ) = @_;
	if ( !( open( CLS_FILE, "<$infile" ) ) ) {
		warn "failed opening $infile\n";
		return (EXIT_FAILURE);
	}

	my @acq;
	my @chain;
	my @cls_num;
	my $count = 0;
	while ( my $line = <CLS_FILE> ) {
		my @words = split( '\s|:', $line );
		my ( $cls_num, $member_num, $acq, $chain ) = @words;
		if ($first) {
			if ( $cls_num < $first ) {
				next;
			}
		}
		if ($last) {
			if ( $cls_num > $last ) {
				last;
			}
		}
		push( @cls_num, $cls_num );
		push( @acq,     $acq );
		push( @chain,   $chain );
		$count++;
	}
	close(CLS_FILE);

	#   The raw data is read up, now break it into cluster-based
	#   arrays.
	my $prev_clus = $cls_num[0];
	my $clust_cnt = -1;
	my $tmp_clust_acq;
	my $tmp_clust_chain;
	for ( my $i = 0 ; $i < @cls_num ; $i++ ) {
		if ( $cls_num[$i] != $prev_clus ) {    # start a new cluster
			$prev_clus = $cls_num[$i];
			$clust_cnt++;
			push( @$clust_acq,   $tmp_clust_acq );
			push( @$clust_chain, $tmp_clust_chain );
			$tmp_clust_acq   = [];
			$tmp_clust_chain = [];
		}
		push( @$tmp_clust_acq,   $acq[$i] );
		push( @$tmp_clust_chain, $chain[$i] );
	}
	push( @$clust_acq,   $tmp_clust_acq );
	push( @$clust_chain, $tmp_clust_chain );
	return (EXIT_SUCCESS);
}

# ----------------------- cls_dumper   ------------------------------
# This is for debugging only.
sub cls_dumper ($ $) {
	my ( $clust_acq, $clust_chain ) = @_;
	for ( my $i = 0 ; $i < @$clust_acq ; $i++ ) {
		my $tmp_acq   = $$clust_acq[$i];
		my $tmp_chain = $$clust_chain[$i];
		for ( my $j = 0 ; $j < @$tmp_acq ; $j++ ) {
			print "$$tmp_acq[$j]:$$tmp_chain[$j] ";
		}
		print "\n";
	}

}

# ----------------------- get_pdb_path ------------------------------
# This returns a path to a *copied* and uncompressed version of the
# pdb file..
# The caller should delete the file when finished.
sub get_pdb_path ($ $) {
	my ( $acq, $TMPDIR ) = @_;
	$acq = lc($acq);
	if ( ( $acq eq '1cyc' ) || ( $acq eq '1aut' ) ) {
		$DB::single = 1;
	}
	my $two_lett = substr( $acq, 1, 2 );
	my $path = "$PDB_TOP_DIR/$two_lett/pdb${acq}.ent.gz";
	if ( !( -f $path ) ) {
		print STDERR "$path not found\n";
		return (undef);
	}
	use File::Copy;
	my $tmppath = "$TMPDIR/pdb${acq}.ent.gz";
	if ( !( copy( $path, $tmppath ) ) ) {
		warn "copy of $acq failed\n";
		return undef;
	}
	my $r = system( @GUNZIP, $tmppath );
	if ( $r != 0 ) {
		warn "gunzip failed on $tmppath\n";
		return undef;
	}
	$tmppath =~ s/\.gz$//;
	if ( !-f ($tmppath) ) {
		warn "Lost uncompressed file $tmppath\n";
		return undef;
	}
	return $tmppath;
}

# ----------------------- log_err    --------------------------------
# Write a message to a log file. This goes in its own function
# since it is a bit verbose and has to do few checks for things
# like the file existing.
sub log_err ($ $ $) {
	my ( $msg, $base_file, $f_sfx ) = @_;
	my $fname = "$base_file$f_sfx";
	if ( !open( BUST, '>>', "$fname" ) ) {
		die "Can't even log errors fail on $fname\n";
	}
	print BUST "$msg\n";
	close(BUST);
}

# ----------------------- check_seq   -------------------------------
# Our pdb reader replaces unknown residues with alanines. Mostly this
# is OK. If, however, we see more than 50 % alanine residues, we
# get suspicious and return EXIT_FAILURE
sub check_seq ( $ ) {
	my $r     = shift;
	my $seq   = coord_get_seq($r);
	my $size  = seq_size($seq);
	my $s     = seq_print($seq);     # Turn sequence into perl string
	my $n_ala = ( $s =~ tr/a// );    # count alanines
	my $frac  = $n_ala / $size;      # Fraction of sequence which is alanine
	if ( $frac > 0.5 ) {
		return EXIT_FAILURE;
	}
	else {
		return EXIT_SUCCESS;
	}
}

# ----------------------- one_clust_write ---------------------------
# Do the work for one pdb cluster.
# Return values:
# > 0 succeeded after trying N files
# < 0 failed after trying N files
# undef bad file error and should stop
sub one_clust_write ($ $ $ $ $ $) {
	my ( $acq, $chain, $TMPDIR, $f_sfx, $lib_list, $all_flag ) = @_;
	my $fail       = 0;
	my $clust_done = undef;

	for ( my $i = 0 ; $i < @$acq ; $i++ ) {
		if ( $clust_done && ( !$all_flag ) ) {
			last;
		}
		my $err   = "$$acq[$i] : $$chain[$i]";
		my $tfile = lc( $$acq[$i] );
		$tfile = "$OUTPUT_BIN_DIR/$tfile$$chain[$i].bin";
		my $t = lc( $$acq[$i] );
		if ( -f $tfile ) {
			$clust_done = 1;
		}
		else {
			# SENSEY: parallelize on single protein layer
			# SENSEY: transport overhead?
			my $path = get_pdb_path( $$acq[$i], $TMPDIR );
			if ( !$path ) {
				return ( undef() );
			}

			#            print "reading $path $t, $$chain[$i]  ";
			my $r = pdb_read( $path, $t, $$chain[$i] );

			#           print "Done $path\n";
			my $c_size;
			my $seq_size;
			if ( !($r) ) {
				log_err( "pdb bust on $err", $PDB_BUST, $f_sfx );
				$fail++;
				next;
			}
			elsif ( ( $c_size = coord_size($r) ) < $MIN_MODEL_SIZE ) {
				log_err( "small $err $c_size", $PDB_BUST, $f_sfx );
				$fail++;
				next;
			}
			elsif ( seq_size( coord_get_seq($r) ) != $c_size ) {
				my $m = "mismatch seq size $seq_size coord size $c_size";
				log_err( $m, $PDB_BUST, $f_sfx );
				$fail++;
				next;
			}
			elsif ( check_seq($r) == EXIT_FAILURE ) {
				log_err( "bad sequence in $err", $PDB_BUST, $f_sfx );
				$fail++;
				next;
			}
			else {
				if ( !coord_2_bin( $r, "$tfile" ) ) {
					log_err( "coord_2_bin error on $err", $PDB_BUST, $f_sfx );
					$fail++;
					next;
				}
				$clust_done = 1;
			}
			if ( !unlink($path) ) {
				warn "Deleting $path failed\n";
				return ( undef() );
			}
		}
		push( @$lib_list, "$t$$chain[$i]" );
	}
	if ($clust_done) {
		return ($fail);
	}
	else {
		return ( -$fail );
	}
}

# ----------------------- write_files  ------------------------------
sub write_files ($ $ $ $ $) {
	my ( $clust_acq, $clust_chain, $f_sfx, $lib_list, $all_flag ) = @_;
	my $TMPDIR = '.';
	if ( $ENV{TMPDIR} ) {
		$TMPDIR = $ENV{TMPDIR};
	}
	if ( !-d $OUTPUT_BIN_DIR ) {
		if ( !mkdir($OUTPUT_BIN_DIR) ) {
			warn "Failed to create output dir $OUTPUT_BIN_DIR: $!\n";
			return undef;
		}
		print "created output bin directory $OUTPUT_BIN_DIR\n";
	}

	for ( my $i = 0 ; $i < @$clust_acq ; $i++ ) {
		if ( $verbosity > 2 ) {
			print "Doing cluster $i\n";
		}
		if ( $$clust_acq[$i] =~ m/cyc/i ) {
			$DB::single = 1;
		}
		
		# SENSEY: move this function to worker
		# SENSEY: parallelize on cluster layer
		my $r = one_clust_write( $$clust_acq[$i], $$clust_chain[$i],
			$TMPDIR, $f_sfx, $lib_list, $all_flag );
		if ( $verbosity > 2 ) {
			print "Done cluster $i\n";
		}

		if ( !( defined($r) ) ) {
			print STDERR "one_clust_write() broke on item $i\n";

			#            return undef;
			next;
		}

		my $msg;
		if ( $r != 0 ) {
			my $succ = 'success';
			if ( $r < 0 ) {
				$msg  = '';
				$succ = 'FAILURE';
				$r    = -$r;
				my $acq   = $$clust_acq[$i];
				my $chain = $$clust_chain[$i];
				for ( my $i = 0 ; $i < @$acq ; $i++ ) {
					$msg = "$msg $$acq[$i]:$$chain[$i]";
				}
			}
			log_err( "Cluster $i $succ after $r attempts", $CLST_BUST, $f_sfx );
			if ($msg) {
				log_err( $msg, $CLST_BUST, $f_sfx );
			}
		}
	}
	return (1);
}

# ----------------------- final_lib_list ----------------------------
# Write the final library list
sub final_lib_list ($ $ $) {
	my ( $libfile, $f_sfx, $lib_list ) = @_;
	if ($f_sfx) {
		$libfile = "${libfile}${f_sfx}";
	}

	if ( !( open( LIBLIST, ">$libfile" ) ) ) {
		warn "Open fail on $libfile: $!\n";
		return EXIT_FAILURE;
	}
	foreach my $i (@$lib_list) {
		print LIBLIST "$i\n";
	}
	close(LIBLIST);
	return EXIT_SUCCESS;
}

# ----------------------- mymain       ------------------------------
sub mymain () {
	use Getopt::Std;
	my $all_flag = undef;    # Write every .bin file
	$verbosity = 0;
	my %opts;
	if ( !getopts( 'av:', \%opts ) ) {
		usage();
		return (EXIT_FAILURE);
	}
	if ( defined( $opts{a} ) ) {
		$all_flag = 1;
	}
	if ( defined( $opts{v} ) ) {
		$verbosity = $opts{v};
	}
	my ( $first_clust, $last_clust );
	if ( $#ARGV >= 1 ) {
		$first_clust = $ARGV[0];
		$last_clust  = $ARGV[1];
	}
	undef %opts;
	my ( @clust_acq, @clust_chain );
	if ( $verbosity > 2 ) {
		print "verbosity is $verbosity\n";
	}

	# SENSEY: move to gearman client,
	# SENSEY: get list of clusters and process each cluster
	# SENSEY: on a personal worker
	my $r = read_cluster_file(
		$INPUT_CLST_LIST, $first_clust, $last_clust,
		@clust_acq,       @clust_chain
	);
	if ( $r == EXIT_FAILURE ) {
		warn "Failed reading cluster input\n";
		return (EXIT_FAILURE);
	}

	#   cls_dumper (\@clust_acq, \@clust_chain);
	my $f_sfx = '';
	if ( defined($first_clust) ) {
		$f_sfx = "_$ARGV[0]_$ARGV[1]_";
	}
	my @lib_list;
	# SENSEY: can be parallelized on cluster layer
	# SENSEY: may be on protein level too
	write_files( \@clust_acq, \@clust_chain, $f_sfx, \@lib_list, $all_flag )
	  || return EXIT_FAILURE;

	if (
		final_lib_list( $OUTPUT_LIB_LIST, $f_sfx, \@lib_list ) == EXIT_FAILURE )
	{
		return (EXIT_FAILURE);
	}

	return (EXIT_SUCCESS);
}

# ----------------------- main         ------------------------------
exit( mymain() );
