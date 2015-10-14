package WurstUpdate::Assert;
use strict;
use warnings;
use POSIX;
use File::Slurp;
use Exporter qw(import);

our @EXPORT_OK = qw(dassert wassert);

sub dassert ($ $) {
	my ( $condition, $message ) = @_;
	($condition) or die($message);
}

sub wassert ($ $) {
	my ( $condition, $message ) = @_;
	if ( !$condition ) {
		warn($message);
		return 0;
	}
	return 1;
}
