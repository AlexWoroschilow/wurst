#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Gearman::Worker;
use Storable qw( thaw );
use List::Util qw( sum );
use Getopt::Lucid qw( :all );

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
	Param("--server")->default("127.0.0.1:7003"),    # server address
	Param("--timeout1")->default(80),                # timeout without server
	Param("--timeout2")->default(30),    # timeout with server but without tasks

);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs )->validate;

my $worker = Gearman::Worker->new;
$worker->job_servers( $opt->get_server );

$worker->register_function(
	'pdb_to_bin' => sub {
		$_[0]->arg;
	}
);

$worker->register_function(
	'bin_to_vec' => sub {
		$_[0]->arg;
	}
);


my $worker_started_at = time();

$worker->work(
	'stop_if' => sub {
		my ( $is_idle, $last_job_time ) = @_;

		my $worker_requested_at = time();

		my $worker_timeout = $opt->get_timeout1;

		# We have to use different timeouts
		# for worker without server and without
		# tasks. Tasks may be started after some
		# pause. Server can be started after some pause too
		# But this should not tage a lot of time
		if ( length $last_job_time ) {
			$worker_started_at = $last_job_time;
			$worker_timeout    = $opt->get_timeout2;
		}
		my $difference = $worker_requested_at - $worker_started_at;

		# This process should be shutted down only
		# if there are not tasks for current worker
		return ( $is_idle && $difference > $worker_timeout );
	}
);

