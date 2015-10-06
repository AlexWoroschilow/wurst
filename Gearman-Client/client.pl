#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/lib";
use lib
"$FindBin::Bin/lib/String/modulos/lib/perl5/site_perl/5.18.1/x86_64-linux-thread-multi";
use String::CRC32;

use Gearman::Client;
use Storable qw( freeze );
my $client = Gearman::Client->new;
$client->job_servers('127.0.0.1');
my $tasks  = $client->new_task_set;
my $handle = $tasks->add_task(
	sum => freeze( [ 3, 5, 12 ] ),
	{
		on_complete => sub { print ${ $_[0] }, "\n" }
	}
);
$tasks->wait;
