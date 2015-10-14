package WurstUpdate::Assert;
use strict;
use warnings;
use POSIX;
use File::Slurp;
use Exporter qw(import);

our @EXPORT_OK = qw(dassert wassert passert);

sub dassert ($ $) {
	my ( $condition, $message ) = @_;
	($condition) or die($message);
}

sub passert ($ $) {
	my ( $condition, $message ) = @_;
	if ( !$condition ) {
		return 0;
	}
	print $message . "\n";
	return 1;
}

sub wassert ($ $) {
	my ( $condition, $message ) = @_;
	if ( !$condition ) {
		warn($message);
		return 0;
	}
	return 1;
}
