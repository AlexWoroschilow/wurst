#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use JSON;
use File::Slurp;
use Gearman::Client;
use Storable qw( freeze );
use Getopt::Lucid qw( :all );
use Data::Dump qw( dump pp );
use WurstUpdate::Assert qw(dassert wassert);
use WurstUpdate::Utils qw(cluster_read_to cluster_each file_line_each);

my ( @specs, $opt, $client, $tasks, $first, $last, @acq, @chain, $json );

# Setup available command line parameters
# with validation, default values and so on
@specs = (
	Param("--cluster")->default("$FindBin::Bin/../clusters90.txt"),
	Param("--list1")->default("$FindBin::Bin/../pdb_all.list"),
	Param("--list2")->default("$FindBin::Bin/../pdb_slm.list"),
	Param("--list3")->default("$FindBin::Bin/../pdb_90n.list"),
	Param("--configfile")->default("$FindBin::Bin/../input/server.conf")
);

# Parse and validate given parameters
$opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( {} );
dassert( $opt->get_cluster,    "File with clusters should be defined" );
dassert( $opt->get_list1,      "File with pdb all list should be defined" );
dassert( $opt->get_list2,      "File with pdb for salami list should be defined" );
dassert( $opt->get_list3,      "File with pdb 90n list should be defined" );
dassert( $opt->get_configfile, "File with server config should be defined" );

$client = Gearman::Client->new;
$client->job_servers( read_file( $opt->get_configfile ) );
$tasks = $client->new_task_set;

# Read cluster from file and
# store in @acq and  @chain
cluster_read_to( $opt->get_cluster, $first, $last, @acq, @chain );
dassert( scalar(@acq),   "Clusters array can not be empty" );
dassert( scalar(@chain), "Clusters chain array can not be empty" );

$json = JSON->new;

cluster_each( \@acq, \@chain, sub {
		my ( @acq, @chain ) = @_;

		my @options = [@acq, @chain, "/src", "/top", "/dst", "12"];
		
		$tasks->add_task( "cluster_to_bin" => $json->encode(@options), {
				on_fail => sub {
					print "Fail cluster_to_bin\n";
				},
				on_complete => sub {
				  }
		} );
} );

$tasks->wait;

file_line_each( $opt->get_list1, sub {
		my (@line) = @_;

		my @options = [@line,"/src", "/top", "/dst", "12"];


		$tasks->add_task( "bin_to_vec" => $json->encode(@options), {
				on_fail => sub {
					print "Fail:\n"; dump(@line);
				},
				on_complete => sub {
				},
		} );
	  }
);

$tasks->wait;
exit;
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
