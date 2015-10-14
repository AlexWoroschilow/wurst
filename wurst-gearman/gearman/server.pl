#!/usr/bin/perl

=head1 NAME

server.pl - Gearman client/worker connector.

=head1 SYNOPSIS

 server.pl

=head1 DESCRIPTION

This is the main executable for L<Gearman::Server>.  It provides
command-line configuration of port numbers, pidfiles, and
daemonization.

=head1 OPTIONS

=over

=item --port=7003 / -p 7003

Set the port number, defaults to 7003.

=item --pidfile=/some/dir/gearmand.pid

Write a pidfile when starting up

=item --debug=1

Enable debugging (currently the only debug output is when a client or worker connects).

=item --accept=10

Number of new connections to accept each time we see a listening socket ready. This doesn't usually
need to be tuned by anyone, however in dire circumstances you may need to do it quickly.

=item --wakeup=3

Number of workers to wake up per job inserted into the queue.

Zero (0) is a perfectly acceptable answer, and can be used if you don't care much about job latency.
This would bank on the base idea of a worker checking in with the server every so often.

Negative One (-1) indicates that all sleeping workers should be woken up.

All other negative numbers will cause the server to throw exception and not start.

=item --wakeup-delay=

Time interval before waking up more workers (the value specified by --wakeup) when jobs are still in
the queue.

Zero (0) means go as fast as possible, but not all at the same time. Similar to -1 on --wakeup, but
is more cooperative in gearmand's multitasking model.

Negative One (-1) means that this event won't happe, so only the initial workers will be woken up to
handle jobs in the queue.

=back

=head1 COPYRIGHT

Copyright 2005-2007, Danga Interactive

You are granted a license to use it under the same terms as Perl itself.

=head1 WARRANTY

This is free software. IT COMES WITHOUT WARRANTY OF ANY KIND.

=head1 AUTHORS

Brad Fitzpatrick <brad@danga.com>

Brad Whitaker <whitaker@danga.com>

=head1 SEE ALSO

L<Gearman::Server>

L<Gearman::Client>

L<Gearman::Worker>

L<Gearman::Client::Async>

=cut

package Gearmand;
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use Carp;
use POSIX ();
use File::Slurp;
use Getopt::Long;
use Scalar::Util();
use Gearman::Util;
use Sys::Hostname;
use Gearman::Server;
use IO::Socket::INET;
use Danga::Socket 1.52;
use Getopt::Lucid qw( :all );
use WurstUpdate::Utils qw(file_write_silent);
use WurstUpdate::Assert qw(dassert wassert passert);

our $graceful_shutdown = 0;

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
	Param("--host")->default(hostname),
	Param("--port")->default(7003)->valid(qr/\d+/),
	Param("--pidfile")->default(""),
	Param("--debug")->default(0)->valid(qr/\d+/),
	Param("--accept")->default(10)->valid(qr/\d+/),
	Param("--wakeup")->default(3),
	Param("--wakeup_delay")->default(1)->valid(qr/\d+/),
	Param("--timeout")->default(20)->valid(qr/\d+/),
	Param("--configfile")->default("$FindBin::Bin/../input/server.conf"),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs );
$opt->validate( { 'requires' => [] } );

dassert( $opt->get_host,       "Host should be defined" );
dassert( $opt->get_port,       "Port should be defined" );
dassert( $opt->get_accept,     "Accept number should be defined" );
dassert( $opt->get_wakeup,     "Wake up number should be defined" );
dassert( $opt->get_timeout,    "Timeout should be defined" );
dassert( $opt->get_configfile, "Config file should be defined" );

# Write server settings wor workers
# this resource should be available for all workers
# they whould get a server settings to connect
my $server_config = join( ":", $opt->get_host, int( $opt->get_port ) );
file_write_silent( $opt->get_configfile, $server_config );
file_write_silent( $opt->get_pidfile,    "$$\n" );

# handled manually, so just ignore
$SIG{'PIPE'} = "IGNORE";

my $server = Gearman::Server->new( 'wakeup' => int( $opt->get_wakeup ),
	'wakeup_delay' => int( $opt->get_wakeup_delay ), );

my $ssock = $server->create_listening_sock( int( $opt->get_port ),
	'accept_per_loop' => int( $opt->get_accept ) );

sub shutdown_graceful {
	if ($graceful_shutdown) {
		return;
	}

	my $ofds = Danga::Socket->OtherFds;
	delete $ofds->{ fileno($ssock) };
	$ssock->close;
	$graceful_shutdown = 1;
	shutdown_if_calm();
}

sub shutdown_if_calm {
	if ( !$server->jobs_outstanding ) {
		exit 0;
	}
}

my $started = time;
Danga::Socket->SetLoopTimeout(500);
Danga::Socket->SetPostLoopCallback( sub {
		passert( ( my $jobs    = $server->jobs ),    "Server have no jobs" );
		passert( ( my $clients = $server->clients ), "Server have no clients" );

		if ( !$jobs && !$clients ) {
			my $current    = time;
			my $difference = $current - $started;

			return !passert( ( $opt->get_timeout < $difference ), "Server shutdown by timeout" );
		}
		$started = time;
		return 1;
} );

Danga::Socket->EventLoop();

# Local Variables:
# mode: perl
# c-basic-indent: 4
# indent-tabs-mode: nil
# End:
