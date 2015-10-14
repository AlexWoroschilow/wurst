package Sensey::Utils;
use strict;
use warnings;
use POSIX;
use Exporter qw(import);
use Data::Dump qw( dump pp );

our @EXPORT_OK = qw(file_each_line read_cluster_file write_files);

sub file_each_line {
	my ( $path, $callback ) = @_;
	if ( !( open( CLS_FILE, "<$path" ) ) ) {
		warn "failed opening $path\n";
		return (EXIT_FAILURE);
	}
	while ( my $line = <CLS_FILE> ) {
		$callback->( split( '\s|:', $line ) );
	}
	close(CLS_FILE);
}

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

		if ( !( $cls_num[$i] eq $prev_clus ) ) {    # start a new cluster

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

	return 1;
}


sub each_cluster ($ $ $) {
	my ($clust_acq, $clust_chain, $callback) = @_;
	for ( my $i = 0 ; $i < @$clust_acq ; $i++ ) {
		$callback->(\$$clust_acq[$i], \$$clust_chain[$i]);
	}
}

