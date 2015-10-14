#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use JSON;
use Gearman::Worker;
use Storable qw( freeze thaw retrieve);
use Storable qw( freeze );

use List::Util qw( sum );
use Getopt::Lucid qw( :all );
use File::Slurp;
use WurstUpdate::Assert qw(dassert wassert passert);
use WurstUpdate::Utils qw(pdb_write_bin);

use Data::Dump qw( dump pp );

my ( @specs, $opt, $worker, $started );

# Setup available command line parameters
# with validation, default values and so on
@specs = (
	Param("--configfile")->default("$FindBin::Bin/../input/server.conf"),
	Param("--timeout1")->default(80),    # timeout without server
	Param("--timeout2")->default(30),    # timeout with server but without tasks
);

# Parse and validate given parameters
$opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( {} );
dassert( $opt->get_configfile, "File with server config should not be empty" );
dassert( $opt->get_timeout1,   "Timeout to shutdown withou server should be defined" );
dassert( $opt->get_timeout2,   "Tmieout to shutdown withou tasks should be defined" );

$worker = Gearman::Worker->new;
$worker->job_servers( read_file( $opt->get_configfile ) );

my $json = JSON->new;

# Define worker function to convert cluster
# of pdb structures to binary files
$worker->register_function( "cluster_to_bin" => sub {
		my ( $cluster_ref, $chain_ref, $src, $top, $dst, $min ) = @{ $json->decode( $_[0]->arg ) };
		dassert( ( my @chain   = @{$chain_ref} ),   "Cluster can not be empty" );
		dassert( ( my @cluster = @{$cluster_ref} ), "Cluster can not be empty" );

		for ( my $i = 0 ; $i < @cluster ; $i++ ) {
			print "Fail: $cluster[$i]\n" if !pdb_write_bin( {
					'source'      => $src,
					'source_top'  => $top,
					'destination' => $dst,
					'code'        => $cluster[$i],
					'chain'       => $chain[$i],
					'minsize'     => $min,
					'gunzip'      => [],
			} );
		}
} );

# Define worker function to convert
# single pdb structure to vector file
$worker->register_function( "bin_to_vec" => sub {
		my ( $pdb, $src, $top, $dst ) = @{ $json->decode( $_[0]->arg ) };

} );

#
$started = time();
$worker->work(
	'stop_if' => sub {
		my ( $is_idle, $last_job_time ) = @_;
		my ( $timeout, $requestred, $difference, $alive );
		passert( !$is_idle, "Worker have no tasks" );

		$timeout    = $opt->get_timeout1;
		$requestred = time();

		# We have to use different timeouts
		# for worker without server and without
		# tasks. Tasks may be started after some
		# pause. Server can be started after some pause too
		# But this should not tage a lot of time
		if ( length $last_job_time ) {
			$started = $last_job_time;
			$timeout = $opt->get_timeout2;
		}
		$difference = $requestred - $started;

		$alive = $is_idle && $difference > $timeout;
		# This process should be shutted down only
		# if there are not tasks for current worker
		return passert( $alive, "Worker shutted down by timeout: $timeout" );
	  }
);

