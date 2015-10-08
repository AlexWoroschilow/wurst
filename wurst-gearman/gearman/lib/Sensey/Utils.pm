package Sensey::Utils;
use strict;
use warnings;
use POSIX;
use Exporter qw(import);

our @EXPORT_OK = qw(file_each_line);

sub file_each_line {
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
