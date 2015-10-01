#!/usr/bin/perl
use strict;
use warnings;
use File::Rsync;
use HTML::Template;
use File::Slurp;
use Term::ANSIColor qw(colored coloralias);
use POSIX qw(strftime);
use Data::Dump qw( dump pp );
use Getopt::Lucid qw( :all );

# Setup color aliases to
# colorize console output
coloralias( 'debug', 'bright_blue' );
coloralias( 'info',  'bright_green' );
coloralias( 'error', 'bright_red' );

# Setup available command line parameters
# with validation, default values and so on
my @specs = (
 Param("--create|-c")->default(1),       #should create target folder
 Param("--optimized|-o")->default(0),    #optimized structures only
 Param("--source|-s")->default("rsync://rsync.cmbi.ru.nl/pdb_redo/"),
 Param("--target|-t")->default("/smallfiles/public/no_backup/pdbredo"),
 Param("--response|-r")
   ->default( "../wurststatus/xml/rsync_pdbredo_" . time . ".xml" ),
);

# Parse and validate given parameters
my $opt = Getopt::Lucid->getopt( \@specs )->validate;
print( colored( "[rsync_pdbredo] Optimized only:\t", 'debug' ) );
print( colored( $opt->get_optimized . "\n",          'debug' ) );
print( colored( "[rsync_pdbredo] Source folder:\t",  'debug' ) );
print( colored( $opt->get_source . "\n",             'debug' ) );
print( colored( "[rsync_pdbredo] Target folder:\t",  'debug' ) );
print( colored( $opt->get_target . "\n",             'debug' ) );
print( colored( "[rsync_pdbredo] Response file:\t",  'debug' ) );
print( colored( $opt->get_response . "\n",           'debug' ) );

# Setup rsync config for both scenario
# First: try to download only optimized structure
# Second: try to update all existed structures
my $update           = $opt->get_optimized ? 0 : 1;
my $compress         = $opt->get_optimized ? 0 : 1;
my $verbose          = $opt->get_optimized ? 1 : 0;
my $prune_empty_dirs = $opt->get_optimized ? 1 : 0;
my $whole_file       = $opt->get_optimized ? 1 : 0;
my @filter = $opt->get_optimized ? [ '+ **/', '+ *.pdb', '- *' ] : [];

# This template engine needs to write a response
# in xml format, they have to be used to build
# a rss stream with Wurst update statuses over time
my $template = HTML::Template->new(
 'utf8'           => 1,
 'case_sensitive' => 1,
 'filename'       => 'response.tmpl',
 'path'           => ['./templates'],
);

# Initialize rsync-perl interface
# this is just a perl-wrapper for real rsync
my $rsync = File::Rsync->new(
 'archive'          => 1,
 'delete'           => 1,
 'update'           => $update,
 'compress'         => $compress,
 'filter'           => @filter,
 'verbose'          => $verbose,
 'prune-empty-dirs' => $prune_empty_dirs,
 'whole-file'       => $whole_file,
 'src'              => $opt->get_source,
 'dest'             => $opt->get_target,
);

# Define UNIX system kill-signal handlers
# to write a current response status
# to notify users about this situation
$SIG{INT} = $SIG{KILL} = $SIG{TERM} = $SIG{HUP} = sub {
 $template->param( 'date'      => time );
 $template->param( 'status'    => "$?" );
 $template->param( 'error'     => "$!" );
 $template->param( 'command'   => pp( $rsync->lastcmd() ) );
 $template->param( 'optimized' => pp( $opt->get_optimized ) );
 die( write_file( $opt->get_response, $template->output() ) );
};
my @test = $rsync->getcmd();
print( colored( "[rsync_pdbredo] Command line arguments:", 'info' ) );
print( colored( pp( $test[0] ) . "\n",                     'info' ) );

# Run rsync to do an update
$rsync->exec();

# Get result status for runned rsync
my $status = $rsync->status();
my @errors = $rsync->err();
my $type   = @errors ? 'error' : 'info';

# Write console output for user
print( colored( "[rsync_pdbredo] Finished, status: ", $type ) );
print( colored( $status . "\n",                       $type ) );
print( colored( "[rsync_pdbredo] " . join( " ", @errors ), $type ) );

# If we are there, rsync was finished,
# just write a response
$template->param( 'date'      => time );
$template->param( 'status'    => pp($status) );
$template->param( 'error'     => pp(@errors) );
$template->param( 'command'   => pp( $rsync->lastcmd() ) );
$template->param( 'optimized' => pp( $opt->get_optimized ) );
die( write_file( $opt->get_response, $template->output() ) );
