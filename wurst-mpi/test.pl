#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use Switch;
use JSON;
use File::Slurp;
use Parallel::MPI::Simple;
use Sensey::Utils qw(file_each_line read_cluster_file write_files);
use Data::Dump qw( dump pp );

MPI_Init();

switch ( ( my $rank = MPI_Comm_rank(MPI_COMM_WORLD) ) ) {

	my $json = JSON->new->allow_nonref;

	case 0 {

		#		my $i = 1;
		#		my $n = MPI_Comm_size(MPI_COMM_WORLD);
		#		file_each_line( "./pdb_90n.list", sub {
		#				my ($proteins) = @_;
		#				if($i >= $n) {
		#					$i = 1;
		#				}
		#
		#				MPI_Send( $json->encode({
		#					'task' => 'pdb_to_bin',
		#					'code' => [$proteins]
		#				}), $i, 123, MPI_COMM_WORLD );
		#
		#				my $msg = MPI_Recv( $i, 123, MPI_COMM_WORLD );
		#				print "$rank received3: '$msg'\n";
		#				$i++;
		#			}
		#		);

		my ( $first, $last, @acq, @chain );
		read_cluster_file( "./clusters90.txt", $first, $last, @acq, @chain );

		each_cluster( \@acq, \@chain, sub {
				my ( $acq, $chain, $temp, $sfx, $lib, $all ) = @_;

				print $json->encode($$acq);

					dump($$acq);
			}
		);

	}

	else {

		while ( ( my $msg = MPI_Recv( 0, 123, MPI_COMM_WORLD ) ) ) {

			my $task = $json->decode($msg);

			switch ( $task->{task} ) {
				case "pdb_to_bin" {

					MPI_Send( "pdb_to_bin $msg", 0, 123, MPI_COMM_WORLD );

					sleep 1;

					append_file( "./test.log", "From server: '$msg'\n" );

					MPI_Send( "pdb_to_bin2 $msg", 0, 123, MPI_COMM_WORLD );

				}
				case "bin_to_vec" {

					$msg = "bin_to_vec $msg";
					MPI_Send( $msg, 0, 123, MPI_COMM_WORLD );
				}

				else {

					my $msg1 = "Unknown task, $msg";
					MPI_Send( $msg1, 0, 123, MPI_COMM_WORLD );

					sleep 1;

				}
			}
		}

	}
	MPI_Finalize();
}

