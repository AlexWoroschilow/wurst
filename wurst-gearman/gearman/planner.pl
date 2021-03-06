#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use JSON;
use File::Slurp;
use Log::Log4perl;
use Gearman::Client;
use Storable qw( freeze );
use Getopt::Lucid qw( :all );
use Data::Dump qw( dump pp );
use Assert qw(dassert);
use WurstUpdate::Utils qw(cluster_read_to cluster_each file_line_each);
use List::MoreUtils qw(zip);

#use lib "/home/other/wurst/salamiServer/v02";
#use Salamisrvini;
#use lib $LIB_LIB;     #initialize in local Salamisrvini.pm;
#use lib $LIB_ARCH;    #initialize in local Salamisrvini.pm;
#use vars qw ( $INPUT_CLST_LIST $OUTPUT_BIN_DIR $PDB_TOP_DIR $OUTPUT_LIB_LIST);

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
	Param("--cluster")->default("$FindBin::Bin/../clusters90.txt"),

	Param("--library")->default("$FindBin::Bin/../lib_all.list"),
	Param("--source")->default("$FindBin::Bin/../tmp"),
#	Param("--library")->default($OUTPUT_LIB_LIST),
#	Param("--source")->default($PDB_TOP_DIR),

	Param("--temp")->default("$FindBin::Bin/tmp"),
	Param("--output")->default("$FindBin::Bin/bin"),

	Param("--list1")->default("$FindBin::Bin/../pdb_all.list"),
	Param("--list2")->default("$FindBin::Bin/../pdb_slm.list"),
	Param("--list3")->default("$FindBin::Bin/../pdb_90n.list"),
	Param("--configfile")->default("$FindBin::Bin/../input/server.conf"),
	Param("--configlog")->default("$FindBin::Bin/../input/logger.conf")
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( {} );

dassert( ( my $cluster = $opt->get_cluster ), "Cluster file should be defined" );
dassert( ( my $library = $opt->get_library ), "Library file should be defined" );
dassert( ( my $output  = $opt->get_output ),  "Output folder should be defined" );
dassert( ( my $source  = $opt->get_source ),  "Source folder should be defined" );
dassert( ( my $temp    = $opt->get_temp ),    "Temp filder should be defined" );

dassert( ( my $list1     = $opt->get_list1 ),      "File with pdb all list should be defined" );
dassert( ( my $list2     = $opt->get_list2 ),      "File with pdb for salami list should be defined" );
dassert( ( my $list3     = $opt->get_list3 ),      "File with pdb 90n list should be defined" );
dassert( ( my $config    = $opt->get_configfile ), "File with server config should be defined" );
dassert( ( my $configlog = $opt->get_configlog ),  "File with server config should be defined" );

Log::Log4perl->init($configlog);
my $log = Log::Log4perl->get_logger("Wurst::Update::Planner");

$log->info("Config loger:\t$configlog");
$log->info("Config server:\t$config");
$log->info("Cluster file: $cluster");
$log->info("Library file: $library");
$log->info("Output folder: $output");
$log->info("Source folder: $source");
$log->info("Temporary folder: $temp");
$log->info("Pdb list1 file: $list1");
$log->info("Pdb list2 file: $list2");
$log->info("Pdb list3 file: $list3");

my $client = Gearman::Client->new;
$client->job_servers( read_file($config) );
my $tasks = $client->new_task_set;

# Read cluster from file and
# store in @acq and  @chain
cluster_read_to( $cluster, my $first, my $last, my @acq, my @chain );

die($log->fatal("Clusters array can not be empty")) if !scalar(@acq);
die($log->fatal("Clusters chain array can not be empty")) if !scalar(@chain);


my $json = JSON->new;

my @library = [];

$log->debug("Start processing clusters to binary");
cluster_each( \@acq, \@chain, sub {
		my ( $acq, $chain ) = @_;
		$log->debug("Start processing clusters to binary ", join(',', @$acq));

		# This parameters should be pass through
		# a network, it may be http or something else
		# we do not know and can not be sure
		# so just encode to json with respect to order
		my $options = $json->encode( [
				$acq,       # Pdb cluster
				$chain,     # Pdb cluster chains
				$source,    # Pdb files source folder
				$temp,      # Temporary folder to store unpacked pdb
				$output,    # Folder to store binary files
				40,         # Minimal structure size
				1           # Should calculate all binary files for a cluster
		] );

		$log->debug("Prepare gearman task settings ", $options);
		$tasks->add_task( "cluster_to_bin" => $options, {
				on_fail => sub {

					# This is totally wrong situation
					# write a report to std error about it
					# for more details see logs from worker
					$log->error("Cluster processing failed  ", join(',', @$acq));

					for ( my $i = 0 ; $i < @$acq ; $i++ ) {
						push( @library, $$acq[$i] );
					}
				},
				on_complete => sub {

					my $response = $json->decode( ${ $_[0] } );
					$log->info("Cluster processing complete  ", join(',', @$acq));
					$log->debug("Worker response received ", ${ $_[0] });

					# Build a library with proteins
					# to make a dump, with correct
					# structures only
					for ( my $i = 0 ; $i < @$response ; $i++ ) {
						push( @library, $$response[$i] );
					}
				  }
		} );
} );

$tasks->wait;
exit;

#file_line_each( $opt->get_list1, sub {
#		my (@line) = @_;
#
#		# This parameters should be pass through
#		# a network, it may be http or something else
#		# we do not know and can not be sure
#		# so just encode to json with respect to order
#		my @options = $json->encode(
#			[ @line, "/src", "/top", "/dst", "12" ]
#		);
#
#		$tasks->add_task( "bin_to_vec" => $json->encode(@options), {
#				on_fail => sub {
#					print "Fail:\n"; dump(@line);
#				},
#				on_complete => sub {
#				},
#		} );
#	  }
#);
#
#$tasks->wait;

#
#file_line_each( $opt->get_list2, sub {
#		my (@line) = @_;
#
#		my $options = {
#			'cluster'     => '',
#			'source'      => '',
#			'source_top'  => '',
#			'destination' => '',
#			'minsize'     => ''
#		};
#
#		$tasks->add_task( 'bin_to_vec' => freeze($options), {
#				on_fail     => sub { print ", fail\n" },
#				on_complete => sub { print "bin_to_vec2 complete!\n"; },
#				on_exception => sub { print ${ $_[0] }, ", exception\n" },
#				retry_count => 3,
#		} );
#} );
#$tasks->wait;
#
#file_line_each( $opt->get_list3, sub {
#		my (@line) = @_;
#
#		my $options = {
#			'cluster'     => '',
#			'source'      => '',
#			'source_top'  => '',
#			'destination' => '',
#			'minsize'     => ''
#		};
#
#		$tasks->add_task( 'bin_to_vec' => freeze($options), {
#				on_fail     => sub { print ", fail\n" },
#				on_complete => sub { print "bin_to_vec complete!\n"; },
#				on_exception => sub { print ${ $_[0] }, ", exception\n" },
#				retry_count => 3,
#		} );
#	  }
#);
#
#$tasks->wait;

