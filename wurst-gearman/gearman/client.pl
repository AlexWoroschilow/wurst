#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Gearman::Client;
use Storable qw( freeze );
use Sensey::Utils qw(file_each_line);

use Getopt::Lucid qw( :all );

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
	Param("--server")->default("127.0.0.1:7003"),              # server address
	Param("--list1")->default("$FindBin::Bin/pdb_all.list"),   # list with codes
	Param("--list2")->default("$FindBin::Bin/pdb_slm.list"),   # list with codes
	Param("--list3")->default("$FindBin::Bin/pdb_90n.list"),   # list with codes
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs )->validate;

my $client = Gearman::Client->new;
$client->job_servers( $opt->get_server );
my $tasks = $client->new_task_set;

file_each_line(
	$opt->get_list1,
	sub {
		my (@proteins) = @_;
		$tasks->add_task(
			'pdb_to_bin' => @proteins,
			{
				on_fail      => sub { print ${ $_[0] }, ", fail\n" },
				on_complete  => sub { print ${ $_[0] }, ", complete\n" },
				on_exception => sub { print ${ $_[0] }, ", exception\n" },
				retry_count  => 3,
			}
		);
	}
);

$tasks->wait;

file_each_line(
	$opt->get_list1,
	sub {
		my (@proteins) = @_;
		$tasks->add_task(
			'bin_to_vec' => @proteins,
			{
				on_fail      => sub { print ${ $_[0] }, ", fail\n" },
				on_complete  => sub { print ${ $_[0] }, ", complete\n" },
				on_exception => sub { print ${ $_[0] }, ", exception\n" },
				retry_count  => 3,
			}
		);
	}
);

$tasks->wait;

