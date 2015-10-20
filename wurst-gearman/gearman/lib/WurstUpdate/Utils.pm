package WurstUpdate::Utils;
use strict;
use warnings;
use POSIX;
use File::Slurp;
use Exporter qw(import);
use Assert qw(dassert wassert passert);
use File::Copy;
#use lib "/home/other/wurst/salamiServer/v02";
#use Salamisrvini;

#use lib $LIB_LIB;     #initialize in local Salamisrvini.pm;
#use lib $LIB_ARCH;    #initialize in local Salamisrvini.pm;

#use Wurst;

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
	return $frac < 0.5;
}

# ----------------------- get_pdb_path ------------------------------
# This returns a path to a *copied* and uncompressed version of the
# pdb file..
# The caller should delete the file when finished.
sub get_pdb_path ($ $ $) {
	my ( $acq, $src1, $src2 ) = @_;
	$acq = lc($acq);
	if ( ( $acq eq '1cyc' ) || ( $acq eq '1aut' ) ) {
#		$DB::single = 1;
	}
	my $two_lett = substr( $acq, 1, 2 );
	my $path = "$src1/$two_lett/pdb${acq}.ent.gz";
	return (undef) if !wassert( ( -f $path ), "$path not found" );

	my $tmppath = "$src2/pdb${acq}.ent.gz";
	return (undef) if !wassert( ( copy( $path, $tmppath ) ), "$path not found" );

	my $r = system( ( "/usr/bin/gunzip", "--force", $tmppath ) );
	return (undef) if !wassert( ( $r == 0 ), "Gunzip failed on $tmppath" );

	$tmppath =~ s/\.gz$//;
	return (undef) if !wassert( ( -f ($tmppath) ), "Lost uncompressed file $tmppath" );

	return $tmppath;
}

sub pdb_write_bin ($) {
	my ($options) = @_;

	dassert( length( my $src  = $options->{src} ),       "Source can not be empty" );
	dassert( length( my $tmp  = $options->{tmp} ),       "Source top can not be empty" );
	dassert( length( my $dst   = $options->{dst} ),        "Destination can not be empty" );
	dassert( length( my $code  = lc( $options->{code} ) ), "Protein code can not be empty" );
	dassert( length( my $chain = $options->{chain} ),      "Protein chain can not be empty" );
	dassert( ( my $min = $options->{min} ), "Minimal size can not be empty" );

	my $file = "$dst/$code$chain.bin";

	return 0 if !wassert( ( my $path = get_pdb_path( $code, $src, $tmp ) ), "[$code] Pdb file not found in: $src" );
	return 0 if !wassert( ( my $read = pdb_read( $path, $code, $chain ) ), "[$code] Can not read pdb coordinates" );
	return 0 if !wassert( ( ( my $c_size = coord_size($read) ) > $min ), "[$code] To small" );
	return 0 if !wassert( ( seq_size( coord_get_seq($read) ) == $c_size ), "[$code] Sizes are different" );
	return 0 if !wassert( check_seq($read), "[$code]Coordinates check failure" );
	return 1 if passert( ( -f $file ), "[$code] Binary file does not exists" );
	return 0 if !wassert( coord_2_bin( $read, $file ), "Can not write bin file: $file" );
	return 0 if !wassert( unlink($path), "[$code] Deleting $path failed" );
	return 1;
}
