#!/usr/bin/perl
# rcsid = $Id: libsrch.pl,v 1.18 2005/10/28 11:21:40 torda Exp $

=pod

=head1 NAME

libsrch.pl - Given a structure, align it to a library of templates

=head1 SYNOPSIS

libsrch.pl [options] I<struct_file> I<struct_lib_list> I< S<[ phd_file ]> >


=head1 DESCRIPTION

Given a structure, align it to every member of a library of
templates.  The sequence is given by I<struct_file>.  The library is
a list of protein names listed in <struct_lib_list>. The last
argument is optional and contains the name of a file with
secondary structure predictions. If it is not present, the script
will look in the directory containing I<struct_file> and strip off
anything that looks like a file extension. Then, it will append
B<.phd> and try to open that (so /boo/bar/1abc.seq gives
/boo/bar/1abc.phd).

If you want to run without secondary structure, it is not enough
to omit the filename. Instead, use the B<-s> option described
below.

=head2 FILE FORMAT

The list of files which make up the template library is in a
simple format. The script will try to read anything that looks

like a four-letter protein name + chain id from the first
column. Leading white space is ignored. A valid form would look
like

   1abc_
   2qrsB
   1xyz  This text after first column is ignored

=head2 Changing library and templates.

Typically, a first run will be made with whatever library we are
using. However, one will often want to add extra .bin files
for a particular sequence. To do that,

=over

=item *

Add the new file names to the list of proteins and give it a name
like F<mylist>.

=item *

Make a directory with a name like I<templates> and put the extra
F<.bin> files in there.

=item *

Run the script with the B<-t> option like:

  perl libsrch.pl -t templates blahblah.seq mylist

=back

=head2 OPTIONS

=over

=item B<-a> I<N>

Print out details of the best I<N> alignments.

=item B<-d> I<modeldir>

Save final models in I<modeldir> instead of the default
directory, B<modeldir>.

=item B<-h> I<N>

After doing alignments, a default number (maybe 50) will be
printed out. Alternatively, you can ask for the I<N> best scoring
alignments to be printed out.

=item B<-m> I<N>

After alignments, I<N> models will be built, otherwise, a small
default number will appear. Set I<N> to zero if you do not want
any models.

=item B<-s>

Do not use secondary structure predictions. This will cause a
different set of parameters to be used in the calculation.

=item B<-t> I<dir1[,dir2,...]>

Add I<dir1> to the list of places to look for template
files. This is a comma separated list, so you can add more
directories.

=back

=head1 OUTPUT

In all output

=over

=item *

B<SW> refers to the result of the second Smith and Waterman.

=item *

B<NW> refers to the result of the Needleman and Wunsch.

=item *

B<cvr> or B<cover> refers to "coverage".  This is the fraction of
sequence residues which are aligned to part of a
structure. Continuing, B<S<sw cvr>> refers to coverage from the
Smith and Waterman calculation.

=item *

The script prints out the coverage in a somewhat pictorial form
which might look like

   ----XXXXX---XXX

where the X's mean a residue was aligned.

=back

=head1 MODELS

Models will be written in PDB format for the best few
sequences. They will get written to a directory called
F<modeldir>. Maybe this should be made an option.

=head1 OPERATION

Currently the script does

=over

=item Smith and Waterman step 1

This is a locally optimal alignment.

=item Smith and Waterman step 2

This is another locally optimal alignment, but forced to pass
through the same path as the first one. It provides a small
extension to the alignment.

=item Needleman and Wunsch

This is a globally optimal alignment, but forced to pass through
the preceding Smith and Waterman.

=back

=head1 QUESTIONS and CHANGES

=item *

The selection of which scores to print out is a bit arbitrary.

=item *

the coverage picture is very ugly. It could be
beautified.

=item *

The coverage picture corresponds to the Smith and
Waterman. Perhaps it should be the Needleman and
Wunsch. Obviously, both are possible, but just a bit ugly.

=cut

#use lib "$ENV{HOME}/pl/lib/i586-linux-thread-multi";  # Where wurst lives after installation
#use lib "/home/stud2004/tmargraf/pl/lib/i686-linux-thread-multi";

use FindBin;

use lib "../../../wurst/blib/arch/auto/Wurst";
use lib "../../../wurst/blib/lib";

use Wurst;

use lib "/home/margraf/crap/Parallel-MPI-Simple-0.03/blib/arch/auto/Parallel/MPI/Simple";
use lib "/home/margraf/crap/Parallel-MPI-Simple-0.03/blib/lib";

use Parallel::MPI::Simple;

use vars qw ($MATRIX_DIR $PARAM_DIR
  $RS_PARAM_FILE $FX9_PARAM_FILE );

#do "$ENV{HOME}/../../torda/c/wurst/scripts/paths.inc" || die $@;

if ($@) {
    die "broke reading paths.inc:\n$@";
}
if ( defined( $ENV{SGE_ROOT} ) ) {
    $MATRIX_DIR = "$ENV{HOME}/../../torda/c/wurst/matrix";
    $PARAM_DIR  = "$ENV{HOME}/../../torda/c/wurst/params";
}

use strict;

use POSIX qw(EXIT_SUCCESS EXIT_FAILURE);

# ----------------------- Defaults  ---------------------------------
# These are numbers you might reasonably want to change.
# They should (will) be changeable by options.
use vars qw ($pvecdir);
$pvecdir       = '/smallfiles/public/no_backup/bm/pdb_all_vec_6mer_struct';

use vars qw( @DFLT_STRUCT_DIRS  @PROFILE_DIRS
  $phd_suffix $bin_suffix $prof_suffix);
*DFLT_STRUCT_DIRS = ['/smallfiles/public/no_backup/bm/pdb_all_bin'];
#*DFLT_STRUCT_DIRS = ['/local/margraf/pdb_all_bin'];
#*DFLT_STRUCT_DIRS = ['/home/stud2004/tmargraf/pdbsnapshot060307']; #/bm/pdb90_bin
*bin_suffix       = \'.bin';


# ----------------------- get_prot_list -----------------------------
# Go to the given filename and get a list of proteins from it.
sub get_prot_list ($) {
    my $f = shift;
    my @a;
    if ( !open( F, "<$f" ) ) {
        print STDERR "Open fail on $f: $!\n";
        return undef;
    }

    while ( my $line = <F> ) {
        chomp($line);
        my @words = split( ' ', $line );
        if ( !defined $words[0] ) { next; }
        $line = $words[0];
        $line =~ s/#.*//;     # Toss comments away
        $line =~ s/\..*//;    # Toss filetypes away
        $line =~ s/^ +//;     # Leading and
        $line =~ s/ +$//;     # trailing spaces.
        if ( $line eq '' ) {
            next;
        }
        substr( $line, 0, 4 ) = lc( substr( $line, 0, 4 ) );    # 1AGC2 to 1agc2
        if ( length($line) == 4 ) {    # Convert 1abc to 1abc_
            $line .= '_';
        }
        push( @a, $line );
    }
    close(F);
    return (@a);
}

# ----------------------- get_path  ---------------------------------
# We have a filename and a list of directories where it could
# be. Return the path if we can find it, otherwise return undef.
sub get_path (\@ $) {
    my ( $dirs, $fname ) = @_;
    foreach my $d (@$dirs) {
        my $p = "$d/$fname";
        if ( -f $p ) {
            return $p;
        }
    }
    return undef;
}

# ----------------------- check_dirs --------------------------------
# Given an array of directory names, check if each one
# exists. Print something if it is missing, but do not give
# up. It could be that there is some crap in the command line
# args, but all the important directories are really there.
# This function is potentially destructive !
# If a directory does not seem to exist, we actually remove it
# from the array we were passed.  This saves some futile lookups
# later on.
sub check_dirs (\@) {
    my $a    = shift;
    my $last = @$a;
    for ( my $i = 0 ; $i < $last ; $i++ ) {
        if ( !-d $$a[$i] ) {
            print STDERR "$$a[$i] is not a valid directory. Removing\n";
            splice @$a, $i, 1;
            $last--;
            $i--;
        }
    }
}

# ----------------------- check_files -------------------------------
# We are given an array of directories and and array of protein
# names and an extension.
# Check if all the files seem to be there.
sub check_files (\@ \@ $) {
    my ( $dirs, $fnames, $ext ) = @_;
    my $errors = 0;
    foreach my $f (@$fnames) {
        my $name = "$f$ext";
        if ( !get_path( @$dirs, $name ) ) {
            $errors++;
            print STDERR "Cannot find $name\n";
        }
    }
    return $errors;
}

# ----------------------- usage   -----------------------------------
sub usage () {
    print STDERR "Usage: \n    $0 -l struct_library \n";
    exit(EXIT_FAILURE);
}

# ----------------------- bad_exit ----------------------------------
# This will run in a server, so if something goes wrong, we
# should at least mail back an indication.  The single parameter
# should be the error message returned by the function which was
# unhappy.
# Should we print to stderr or stdout ?
# This should not matter since we have grabbed both file handles.
sub bad_exit ( $ )
{
    my $msg = shift;
    restore_handlers();  # otherwise an ugly loop is possible
    print STDERR "Error: \"$msg\"\n";
    exit (EXIT_FAILURE);
}

# ----------------------- catch_kill     ----------------------------
# The main thing is, if we get a KILL or TERM, to call exit and get
# out of here. This means there is a better chance of closing files
# wherever we were up to.
sub catch_kill
{
    my ($sig) = @_;
    bad_exit ("signal $sig received");

}

# ----------------------- kill_handlers  ----------------------------
# set up signal catchers so we can call exit() and die gracefully.
sub kill_handlers ()
{
    $SIG{INT } = \&catch_kill;
    $SIG{QUIT} = \&catch_kill;
    $SIG{TERM} = \&catch_kill;
}

# ----------------------- restore_handlers --------------------------
# If we are at the stage of mailing, we no longer want to trap
# interrupts. Otherwise, they will call the bad_exit routine again.
sub restore_handlers ()
{
    $SIG{INT } = 'DEFAULT';
    $SIG{QUIT} = 'DEFAULT';
    $SIG{TERM} = 'DEFAULT';
}

# ----------------------- reduce_priority ---------------------------
# We can reduce our own priority to be sociable.
sub reduce_priority ()
{
    my $PRIO_PGRP = 1;
    my $low_priority = 2;      # 0 is normal. 10 is very low.
    setpriority ($PRIO_PGRP, getpgrp (0), $low_priority);
}


# ----------------------- mymain  -----------------------------------
# Arg 1 is a structure file. Arg 2 is a structure list file.
sub mymain () {
    use Getopt::Std;
    my (%opts);
    my @struct_list;
    my ( $structfile,  $libfile );
    my $fatalflag = undef;
    my @struct_dirs = @DFLT_STRUCT_DIRS;

    print @struct_dirs;
    if ( !getopts( 'a:d:h:s:t:q:l:', \%opts ) ) {
        usage();
    }
    if ( defined( $opts{l} ) ) { $libfile      = $opts{l} }
    else{
        print STDERR "Please give me a structure library / file\n";
        usage();
    }
    check_dirs(@struct_dirs);
    if ( @struct_dirs == 0 ) {
        die "\nNo valid structure directory. Stopping.\n";
    }

    @struct_list = get_prot_list($libfile);
    #print @struct_list;
	if($fatalflag){
		print "FATAL: get_prot_list $libfile \n";
        print STDERR "struct dirs were @struct_dirs\n";
        print STDERR "Fatal problems\n";
        return EXIT_FAILURE;
    }


    print STDERR "doing lib\n";
    
	print STDERR "about to distribute jobs \n";
	# Dole out jobs to all processes
	my $size = MPI_Comm_size(MPI_COMM_WORLD);
	$size--;
    my $i = 0;
    my $res_idx = 0;
    while($i<(scalar @struct_list)){
        MPI_Send($struct_list[$i], ($i%$size)+1, 123, MPI_COMM_WORLD);
        $i++;    
    }
    
    print STDERR "done lib\n";
    
    # shutting down worker processes
	print STDERR "about kill workers\n";
    for ( my $i = 0 ; $i < $size ; $i++ ) {
		MPI_Send("quit", $i+1, 123, MPI_COMM_WORLD);
	}

	print STDERR "done killing workers\n";
    print
"__________________________________________________________________________\n",
      "Wurst gegessen at ", scalar( localtime() ), "\n";
    my ( $user, $system, $crap, $crap2, $host );
    ( $user, $system, $crap, $crap2 ) = times();
    printf "I took %d:%d min user and %.0f:%.0f min sys time\n", $user / 60,
      $user % 60, $system / 60, $system % 60;
    use Sys::Hostname;
    $host = hostname() || { $host = 'no_host' };
    print "Run on $host\n";

    return EXIT_SUCCESS;
}

# ----------------------- main    -----------------------------------
print "Hello from perl\n";
MPI_Init();
my $rank = MPI_Comm_rank(MPI_COMM_WORLD);
my $size = MPI_Comm_size(MPI_COMM_WORLD);
if ($rank > 0) {
	my $msg = "Hello, I'm $rank";
	MPI_Send($msg, 0, 123, MPI_COMM_WORLD);
    my @struct_dirs = @DFLT_STRUCT_DIRS;
    my $gauss_err = 0.4;
    my $tau_error      = \0.15;
    my $ca_dist_error  = \0.385;
    my $corr_num       = \4;
    my $classfile = '/home/margraf/andrew/scripts/classfile';
    my $PVEC_CA_DIR = '/smallfiles/public/no_backup/bm/pdb90_vec_7mer_ca_mod';
    my $CA_CLASSFILE  = \'/smallfiles/public/no_backup/bm/F7_ca_mod';
    my $classfcn = aa_strct_clssfcn_read($classfile, $gauss_err);
    my $classfcn_ca = ac_read_calpha ($CA_CLASSFILE, $tau_error,                                                
                                      $ca_dist_error, $corr_num);
    
    print "$msg \n";	
	$msg = MPI_Recv(0, 123, MPI_COMM_WORLD);
	while($msg ne "quit"){
        my $struct_path = get_path( @struct_dirs, "$msg$bin_suffix" );
		if( -e "$pvecdir/$msg.vec" ){    
            ;
        }
        else {
            my $struct = coord_read($struct_path);
            unless (-e $struct_path){
                print "failed to read $msg \n";
            }
            else{
	            my $pvec = strct_2_prob_vec($struct, $classfcn, 1);
                prob_vec_write($pvec, "$pvecdir/$msg.vec");
            }
        }
        if( -e "$PVEC_CA_DIR/$msg.vec" ){    
            ;
        }
        else {
            my $struct = coord_read($struct_path);
            unless (-e $struct_path){
                print "failed to read $msg \n";
            }
            else{
	            my $pvec = calpha_strct_2_prob_vec($struct, $classfcn_ca, 1);
                prob_vec_write($pvec, "$PVEC_CA_DIR/$msg.vec");
            }
        }
		$msg = MPI_Recv(0, 123, MPI_COMM_WORLD);
	}
    #MPI_Barrier(MPI_COMM_WORLD);
}
else {
	print "size is $size \n";
	my $i = 0;
	for($i=1; $i<$size; $i++){
		my $msg = MPI_Recv($i, 123, MPI_COMM_WORLD);
		print "$rank received: '$msg'\n";
	}
	mymain();
}
MPI_Finalize();

#exit( mymain() );
exit();
