#!/usr/local/bin/perl -w-
#------------------------------------------------------------------------------
#   rcsfreeze.pl
#
#   Copyright © 1999-2000 Norbert E. Gruener <nog@MPA-Garching.MPG.DE>
#
#   Rewrite of the shell script rcsfreeze.sh from Paul Eggert as part of
#   the RCS package: rcsfreeze.sh,v 4.6 1993/11/03 17:42:27 eggert Exp
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2
#   of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#   For changes see file 'ChangeLog'
#
#   RCS-Id: @(#)rcsfreeze.pl,v 1.8 2000/06/06 06:21:12 nog Exp
#
#------------------------------------------------------------------------------

=head1 NAME

B<rcsfreeze> - freeze a configuration of sources checked in under RCS

=head1 SYNOPSIS

B<rcsfreeze> [B<-help>] [B<-man>] [B<-version>] I<symrev>

=head1 OPTIONS AND ARGUMENTS

=over 10

=item B<-help>

Print a brief help message and exit.

=item B<-man>

Print the manual page and exit.

=item B<-version>

Print the version number and exit.

=item I<symrev>

The symbolic revision number.

=back

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

=cut

#+-----------------------------------------------------------------------------
#| declarations
#+-----------------------------------------------------------------------------
use strict;
use English;
use File::Basename;
use IO::Dir;
use Rcs 0.09;

#+-----------------------------------------------------------------------------
#| define local variables & set default values
#+-----------------------------------------------------------------------------
$::VERSION     = ' 1.8 ';
$::Debugging   = 0;
$::Symb_logmsg = '';
$::XNAME       = basename($0);
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

#+-----------------------------------------------------------------------------
#| main program
#+-----------------------------------------------------------------------------

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

#+-----------------------------------------------------------------------------
#| analyse input
#+-----------------------------------------------------------------------------
sub parse_input {

    use Pod::Usage;
    use Getopt::Long;

#      $Getopt::Long::debug      = 1;
    $Getopt::Long::ignorecase = 0;
    $Getopt::Long::autoabbrev = 1;

#   Define options
    %::options = (
                   "help"     => 0,
                   "man"      => 0,
                   "version"  => 0,
                   "Debug"    => 0,
                  );

#   Parse options
    GetOptions(\%::options,
               "help",
               "man",
               "version",
               "Debug")    || pod2usage(-verbose => 0);

    pod2usage(-verbose => 1) if ($::options{help});
    pod2usage(-verbose => 2) if ($::options{man});

    if ($::options{version}) {
        die " $::XNAME - freeze a configuration of sources checked in under RCS\n".
            " - version: $::VERSION \n".
            " - Copyright © 1999-2000 ".
            "Norbert E. Gruener <nog\@MPA-Garching.MPG.DE>\n";
    }

    pod2usage(-verbose => 0, -message => "Too many arguments ...")               if (@ARGV > 1);
    pod2usage(-verbose => 0, -message => "Symbolic revision number missing ...") if (@ARGV < 1);

    $::Debugging = $::options{Debug};
    if ($::Debugging) { eval "use diagnostics;"; }

    $::Symrev = shift @ARGV;
    $::Debugging && print "Symb number: $::Symrev \n";
}

#+-----------------------------------------------------------------------------
#| ask for log message for the symbolic version
#+-----------------------------------------------------------------------------
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

#+-----------------------------------------------------------------------------
#| set RCS symbolic revision number and save the log message
#+-----------------------------------------------------------------------------
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

#+-----------------------------------------------------------------------------
#| signal handler
#+-----------------------------------------------------------------------------
sub sig_handler {
    my ($sig) = @ARG;

    die "\nCaught a SIG$sig -- execution aborted ... \n";
}

__END__

=head1 SEE ALSO

L<rlog(1)>,
L<rcsclean(1)>

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

Rewrite of the shell script rcsfreeze.sh from Paul Eggert as part of
the RCS package: rcsfreeze.sh,v 4.6 1993/11/03 17:42:27 eggert Exp

=head1 COPYRIGHT AND DISCLAIMER

©S< >1999-2000S< Norbert E. Gruener E<lt>nog@MPA-Garching.MPG.DEE<gt>.     >
S<All rights reserved.                                                >

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=head1 VERSION

Version 1.8

=cut
