package WurstUpdate::Utils;
use strict;
use warnings;
use POSIX;
use File::Slurp;
use Exporter qw(import);
use Assert qw(dassert wassert);
use File::Copy;

our @EXPORT_OK =
  qw(file_line_each file_write_silent cluster_read_to cluster_each pdb_write_bin)
  ;

sub file_line_each {
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

sub file_write_silent ($ $) {
	my ( $file_path, $content ) = @_;
	if ($file_path) {
		write_file( $file_path, $content );
	}
}

sub cluster_read_to ($ $ $ \@ \@) {
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

sub cluster_each ($ $ $) {
	my ( $clust_acq, $clust_chain, $callback ) = @_;
	for ( my $i = 0 ; $i < @$clust_acq ; $i++ ) {
		$callback->( @$clust_acq[$i], @$clust_chain[$i] );
	}
}

# ----------------------- get_pdb_path ------------------------------
# This returns a path to a *copied* and uncompressed version of the
# pdb file..
# The caller should delete the file when finished.
sub pdb_path_get ($ $ $ @) {
	my ( $acq, $source, $source_top, @gunzip ) = @_;
	$acq = lc($acq);
	if ( ( $acq eq '1cyc' ) || ( $acq eq '1aut' ) ) {

		#		$DB::single = 1;
	}
	my $two_lett = substr( $acq, 1, 2 );
	my $path = "$source_top/$two_lett/pdb${acq}.ent.gz";
	if ( !( -f $path ) ) {
		print STDERR "$path not found\n";
		return (undef);
	}
	my $tmppath = "$source/pdb${acq}.ent.gz";
	if ( !( copy( $path, $tmppath ) ) ) {
		warn "copy of $acq failed\n";
		return undef;
	}
	my $r = system( @gunzip, $tmppath );
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

sub pdb_write_bin ($) {
	my ($options) = @_;

	dassert( length( my $source      = $options->{src} ),        "Source can not be empty" );
	dassert( length( my $source_top  = $options->{top} ),        "Source top can not be empty" );
	dassert( length( my $destination = $options->{dst} ),        "Destination can not be empty" );
	dassert( length( my $code        = lc( $options->{code} ) ), "Protein code can not be empty" );
	dassert( length( my $chain       = $options->{chain} ),      "Protein chain can not be empty" );
	dassert( ( my $minsize = $options->{min} ),  "Minimal size can not be empty" );
	dassert( ( my @gunzip  = $options->{uzip} ), "G unzip should not be empty" );
#
#	return 0 if !wassert( ( my $path = get_pdb_path( $code, $source, $source_top, @gunzip ) ), "Pdb file not found in: $source" );
#	return 0 if !wassert( ( my $r = pdb_read( $path, $code, $chain ) ), "Can not read pdb coordinates" );
#	return 0 if !wassert( ( ( my $c_size = coord_size($r) ) > $minsize ), "To small" );
#	return 0 if !wassert( ( seq_size( coord_get_seq($r) ) == $c_size ), "Sizes are different" );
#	return 0 if !wassert( ( check_seq($r) != EXIT_FAILURE ),            "Coordinates check failure" );
#	return 0 if !wassert( coord_2_bin( $r, "$destination/$code$chain.bin" ), "Can not write bin file: $destination/$code$chain.bin" );
#	return 0 if !wassert( unlink($path), "Deleting $path failed" );
	return 1;
}
