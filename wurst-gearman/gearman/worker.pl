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
use Log::Log4perl;
use Assert qw(dassert);
use WurstUpdate::Utils qw(pdb_write_bin);
use Data::Dump qw( dump pp );

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
	Param("--configfile")->default("$FindBin::Bin/../input/server.conf"),
	Param("--configlog")->default("$FindBin::Bin/../input/logger.conf"),
	Param("--timeout1")->default(80),    # timeout without server
	Param("--timeout2")->default(30),    # timeout with server but without tasks
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( {} );

dassert( ( my $configserver = $opt->get_configfile ), "File with server config should not be empty" );
dassert( ( my $configloger  = $opt->get_configlog ),  "File with server config should not be empty" );
dassert( ( my $timeout1     = $opt->get_timeout1 ),   "Timeout to shutdown without server should be defined" );
dassert( ( my $timeout2     = $opt->get_timeout2 ),   "Tmieout to shutdown without tasks should be defined" );

Log::Log4perl->init($configloger);
my $log = Log::Log4perl->get_logger("Wurst::Update::Worker");

$log->info("Config server: $configserver");
$log->info("Config loger: $configloger");
$log->info("Timeout without server: $timeout1");
$log->info("Timeout without tasks: $timeout2");

my $json    = JSON->new;
my $started = time();
my $worker  = Gearman::Worker->new;
$worker->job_servers( read_file($configserver) );

# Define worker function to convert cluster
# of pdb structures to binary files
$worker->register_function( "cluster_to_bin" => sub {
		$log->debug( "Received a cluster_to_bin task ", $_[0]->arg );

		# Data have been transfered over network
		# should be enpacked from json
		my ( $ref1, $ref2, $src, $tmp, $dst, $min, $all ) = @{ $json->decode( $_[0]->arg ) };
		dassert( ( my @chain   = @{$ref2} ), "Cluster can not be empty" );
		dassert( ( my @cluster = @{$ref1} ), "Cluster can not be empty" );

		$log->debug( "Cluster ",        join( ',', @cluster ) );
		$log->debug( "Cluster chains ", join( ',', @chain ) );
		$log->debug( "Source folder ",  $src );
		$log->debug( "Temporary folder ",       $tmp );
		$log->debug( "Destination folder ",     $dst );
		$log->debug( "Minimal structure size ", $min );
		$log->debug( "Process all ",            $all );

		my $total   = 0;
		my $success = 0;
		my @library = [];

		for ( my $i = 0 ; $i < @cluster ; $i++ ) {

			if ( $success && !$all ) {
				last;
			}

			my $pdb       = $cluster[$i];
			my $pdb_chain = $chain[$i];
			$log->debug( "Pdb process ",       $pdb );
			$log->debug( "Pdb chain process ", $pdb_chain );

			my $config = {
				'src'   => $src,          # Pdb files source folder
				'tmp'   => $tmp,          # Temporary folder to store unpacked pdb
				'dst'   => $dst,          # Folder to store binary files
				'code'  => $pdb,          # Pdb protain name
				'chain' => $pdb_chain,    # Pdb protain chain
				'min'   => $min,          # Minimal size
			};

			$total++;
			if ( pdb_write_bin($config) ) {
				$log->info( "Pdb process success ", $pdb );

				# Fill library with correct
				# calculated structures needs to write
				# a file with library proteins
				push( @library, $pdb );
				$success++;
				next
			}
			$log->info( "Pdb process fail ", $pdb );
		}
		$log->debug( "Send response ", join( ',', @library ) );
		$json->encode( \@library );
} );

# Define worker function to convert
# single pdb structure to vector file
#$worker->register_function( "bin_to_vec" => sub {
#		my ( $pdb, $src, $top, $dst ) = @{ $json->decode( $_[0]->arg ) };
#
#} );

#
$worker->work( 'stop_if' => sub {
		my ( $is_idle, $last_job_time ) = @_;
		$log->debug("Worker is idle") if $is_idle;

		my $timeout    = $timeout1;
		my $requestred = time();

		# We have to use different timeouts
		# for worker without server and without
		# tasks. Tasks may be started after some
		# pause. Server can be started after some pause too
		# But this should not tage a lot of time
		if ( length $last_job_time ) {
			$started = $last_job_time;
			$timeout = $timeout2;
		}
		my $difference = $requestred - $started;
		$log->debug( "Current timeout: ", $timeout );

		my $should_die = $is_idle && $difference > $timeout;
		$log->debug( "Should die: ", $should_die ? "true" : "false" );

		# This process should be shutted down only
		# if there are not tasks for current worker
		$log->info( "Shutdown in: ", ( $timeout - $difference ) );
		$log->info("Shutdown") if $should_die;
		return $should_die;
} );

