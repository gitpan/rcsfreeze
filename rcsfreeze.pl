#!/usr/local/bin/perl -w-
# ******************************************************************************
# rcsfreeze.pl 
# Copyright © 1999 Norbert E. Gruener (nog@MPA-Garching.MPG.DE)
# Rewrite of the shell script rcsfreeze.sh from Paul Eggert as part of 
# the RCS package: rcsfreeze.sh,v 4.6 1993/11/03 17:42:27 eggert Exp
# For changes see file 'ChangeLog'
#
# RCS-Id: @(#)rcsfreeze.pl,v 1.7 1999-10-27 08:13:15+02 nog Exp
#
# ******************************************************************************

#*******************************************************************************
# declarations
#*******************************************************************************
use strict;
use English;
use File::Basename;
use IO::Dir;
use Rcs 0.09;

#*******************************************************************************
# define local variables & set default values
#*******************************************************************************
$::VERSION      = ' 1.7 ';
$::Debugging    = 0;
$::Symb_logmsg  = '';
$::XNAME        = basename($0);
autoflush STDOUT 1;

Rcs->arcext(',v');
Rcs->bindir('/usr/bin');
if ($OSNAME eq 'aix' and 
    $ENV{DOMAIN} =~ /MPA-Garching/) { Rcs->bindir('/usr/local/appl/rcs-5.7/bin'); }
elsif ($OSNAME eq 'aix')            { Rcs->bindir('/usr/local/bin'); }
elsif ($OSNAME eq 'solaris')        { Rcs->bindir('/usr/local/bin'); }
elsif ($OSNAME eq 'linux')          { Rcs->bindir('/usr/bin'); }

$SIG{'INT'}  = \&sig_handler;
$SIG{'QUIT'} = \&sig_handler;
$SIG{'ILL'}  = \&sig_handler;
$SIG{'KILL'} = \&sig_handler;

#*******************************************************************************
# main program
#*******************************************************************************
parse_input();

retrieve_logmsg();

my $rcs_dir = './RCS';
if (!(lstat ($rcs_dir))) { $rcs_dir = '.'; }
$::Debugging && print "RCS-Dir: $rcs_dir \n";

my $dir_fh = IO::Dir->new();
$dir_fh->open($rcs_dir);
my @filenames = $dir_fh->read;
$dir_fh->close;

foreach my $file (@filenames) {
    if ($file !~ m/(.*),v/) { next; }
    print "Working on $1 ...";
    my $rc = set_rcs_symrev('.', $rcs_dir, $1);
    print "  done  \n" unless $rc;
}

exit 0;

#*******************************************************************************
# analyse input
#*******************************************************************************
sub parse_input {
    use Getopt::Long;
#     $Getopt::Long::debug = 1;
    $Getopt::Long::ignorecase = 0;
    undef $::opt_h; undef $::opt_v;
    if (!(GetOptions("h", "v",
                     "D"   => \$::Debugging))) { help("Error while parsing input ..."); }
    if ($::opt_h)                              { help(); }
    if ($::opt_v)                              { die "$::XNAME - version: $::VERSION ".
                                                     "- author: Norbert E Gruener <nog\@MPA-Gaching.MPG.DE>\n"; }
    if ($#ARGV == -1)                          { help("Symbolic revision number missing ..."); }
    if ($#ARGV > 0)                            { help("Too many Options ..."); }
    if ($::Debugging) { eval "use diagnostics;"; }
    
    $::Symrev = shift @ARGV;
    $::Debugging && print "Symb number: $::Symrev \n";
}

#*******************************************************************************
# ask for log message for the symbolic version
#*******************************************************************************
sub retrieve_logmsg {
    my $logmsg;

    print "rcsfreeze>> Symbolic revision number used: $::Symrev\n";
    print "rcsfreeze>> Give log message, describing your configuration\n";
    print "rcsfreeze>> (end with EOF or single '.'):\n";
    while (defined($logmsg = <STDIN>)) {
        last if ($logmsg =~ m/^.$/);
        $::Symb_logmsg .= "$::Symrev: $logmsg";
    }
}

#*******************************************************************************
# set RCS symbolic revision number and save the log message
#*******************************************************************************
sub set_rcs_symrev {
    my $wdir = shift;
    my $rdir = shift;
    my $file = shift;

    my $rcs_obj = Rcs->new;
    $rcs_obj->workdir($wdir);
    $rcs_obj->rcsdir($rdir);
    $rcs_obj->file($file);

    if ($rcs_obj->symrev($::Symrev)) { 
        warn "\a\n\nSymbolic revision number $::Symrev already in use: Version not frozen ... \n\n"; 
        return 1; 
    }

    my %comments = $rcs_obj->comments;
    my $head     = $rcs_obj->head;
    $::Debugging && print "Head: $head \nComment:\n";
    $::Debugging && print "$comments{$head}\n";

    $rcs_obj->rcs("-n$::Symrev: ");
    $rcs_obj->rcs("-m$::Symrev:Freeze-Version: $::Symrev\n$::Symb_logmsg\n$comments{$head}");
    undef $rcs_obj;
    return 0;
}

#*******************************************************************************
# signal handler
#*******************************************************************************
sub sig_handler(\@) {
    my ($sig) = @ARG;
    die "\nCaught a SIG$sig -- execution aborted ... \n";
}

#*******************************************************************************
# display help text
#*******************************************************************************
sub help(@) {
    warn "$::XNAME: @ARG\n" if @ARG;
    die <<EOF;
    
$::XNAME - assign a symbolic revision number to a configuration of RCS files
               for more information, type \"perldoc $::XNAME\"
      
usage:     $::XNAME symrev | -v | -h 
arguments:
          symrev        symbolic revision number
          -v            print the version
          -h            display help text
EOF
}

__END__

=pod

=head1 NAME

rcsfreeze - freeze a configuration of sources checked in under RCS

=head1 SYNOPSIS

rcsfreeze symrev

=head1 DESCRIPTION

B<rcsfreeze> assigns the specified symbolic revision number B<symrev> 
to a set of RCS files that form a valid configuration. The symbolic revision
number must be unique. It is assigned to the most recent revision of each RCS 
file of the main trunk.

B<rcsfreeze> prompts for a B<log message>. The log message must be terminated
by end-of-file or by a line containing B<.> by itself. The according lines are 
labeled by its symbolic revision number. This log message can be retrieved by 
the B<rlog> command

This script works only on all RCS files in the current directory at one time. 
It is important that all changed files are checked in (there are no precautions 
against any error in this respect). Run B<rcsclean> first and see whether any 
sources remain in the current directory.

=head1 README

 rcsfreeze.pl is a perl script to freeze a configuration of 
 sources checked in under RCS. 

 This perl script is a complete rewrite of the rcsfreeze.sh shell
 script contained in  the RCS package with its RCS ID:
       "rcsfreeze.sh,v  4.6  1993/11/03 17:42:27 eggert Exp"
 The major differences between the shell script and the perl
 script are the following:
 the input argument "symb revision number" 
     - is optional for the shell script. Internally an unique
       revision number is used. 
     - is mandatory for the perl script. Only this symbolic
       revision number is used.
 the log message
     - is saved by the shell script in its own file 
       rcsfreeze.log. But there are no tools available to
       retrieve the log messages for a given revision number.
     - is saved by the perl script amongst the other RCS log
       messages.  Therefore they can be retrieved with the 
       appropriate rlog command. 

 For more information on how to use the script, see the pod
 documentation or view the man pages.

 For instructions on how to install the script, see the file
 INSTALL.

 Problems, questions, etc. may be sent to nog@MPA-Garching.MPG.DE
 
 For Copyright see the pod documentation.

=head1 PREREQUISITES

 module IO::Dir
 module Rcs

=head1 OSNAMES

any UNIX system

=head1 SCRIPT CATEGORIES

 Version_Control
 Software Configuration Management
 Software Development

=head1 AUTHOR

S<Norbert E. Gruener E<lt>nog@MPA-Garching.MPG.DEE<gt>           >

=head1 COPYRIGHT

Copyright © 1999 S<Norbert E. Gruener E<lt>nog@MPA-Garching.MPG.DEE<gt>>
S<All rights reserved.                                           >

This program is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 VERSION

Version 1.7

=head1 SEE ALSO

L<rlog(1)>,
L<rcsclean(1)>

=cut


