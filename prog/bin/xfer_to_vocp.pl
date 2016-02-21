#!/usr/bin/perl -T -w
use strict;


my $DefaultLine = 'ttyS1';

my $Signal = 10; # USR1

my $AttemptDefault = 1; # if $DefaultLine not found, attempt to signal the single vgetty process

# my $License = join( "\n",  
# qq|####################  xfer_to_vocp.pl  ###################|,
# qq|####                                                  ####|,
# qq|####  Copyright (C) 2003 Pat Deegan, Psychogenic.com  ####|,
# qq|####               All rights reserved.               ####|,
# qq|####                                                  ####|,
# qq|#                                                        #|,
# qq|#                 VOCP Call in progress                  #|,
# qq|#                      to voicemail                      #|,
# qq|#                                                        #|,
# qq|#              http://www.VOCPsystem.com                 #|,
# qq|#                                                        #|,
# qq|#                                                        #|,
# qq|#                                                        #|,
# qq|#   This program is free software; you can redistribute  #|,
# qq|#   it and/or modify it under the terms of the GNU       #|,
# qq|#   General Public License as published by the Free      #|,
# qq|#   Software Foundation; either version 2 of the         #|,
# qq|#   License, or (at your option) any later version.      #|,
# qq|#                                                        #|,
# qq|#   This program is distributed in the hope that it will #|,
# qq|#   be useful, but WITHOUT ANY WARRANTY; without even    #|,
# qq|#   the implied warranty of MERCHANTABILITY or FITNESS   #|,
# qq|#   FOR A PARTICULAR PURPOSE.  See the GNU General       #|,
# qq|#   Public License for more details.                     #|,
# qq|#                                                        #|,
# qq|#   You should have received a copy of the GNU General   #|,
# qq|#   Public License along with this program; if not,      #|,
# qq|#   write to the Free Software Foundation, Inc., 675     #|,
# qq|#   Mass Ave, Cambridge, MA 02139, USA.                  #|,
# qq|#                                                        #|,
# qq|#   You may contact the author, Pat Deegan,              #|,
# qq|#   at http://www.psychogenic.com and                    #|,
# qq|#                                                        #|,
# qq|##########################################################|,
# );


=head1 NAME

xfer_to_vocp.pl - Allows transfer of ongoing call to VOCP voice
messaging system

=head1 SYNOPSIS

/path/to/xfer_to_vocp.pl [TTYSX]

=head1 DESCRIPTION

This utility allows the user to easily transferring a call in progress, i.e. 
a call for which you have already picked up the line and are communicating with
the caller, to the VOCP system.


=head1 AUTHOR INFORMATION

LICENSE

    VOCP call transfer utility, part of the VOCP voice messaging system.
    Copyright (C) 2003 Patrick Deegan
	All rights reserved.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


Address bug reports and comments through the contact info found on 
http://www.VOCPsystem.com or come and see me at http://www.psychogenic.com.


=cut
$ENV{'PATH'} = '/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin';
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'}="/etc/bashrc";
if ($ENV{'HOME'} =~ m|^(.*)$|)
{
	# Cheap taint checking
	$ENV{'HOME'} = $1;
	# As we don't actually use the $HOME, it /shouldn't/ matter
	# if we set it to some bogus know to be safe value
	# but since it's used by X display forwarding we need to leave
	# it unmodified.
	
}

my $suppliedLine = shift @ARGV;
my $line;

if ($suppliedLine && $suppliedLine =~ m|^(\w+\d*)$|)
{
	$line = $1;
} else {
	$line = $DefaultLine;
}

# main
{
	my $psLineCommand = "ps waux | grep 'bin/[v]getty $line'";
	
	my @listing = `$psLineCommand`;
	my $owner;
	my $foundPID;
	foreach my $psline (@listing)
	{
		last if $foundPID;
		if ($psline =~ m|^\s*(\S+)\s+(\d+).*[\w\d\/]+bin/vgetty\s+$line|)
		{
			$owner = $1;
			$foundPID = $2;
		}
	}
	
	unless ($foundPID && $AttemptDefault)
	{
		$psLineCommand = "ps waux | grep bin/[v]getty";
		@listing = `$psLineCommand`;
		if (scalar @listing == 1 && $listing[0] =~ m|^\s*(\S+)\s+(\d+).*[\w\d\/]+bin/vgetty\s+[\w\d]+|)
		{
			$owner = $1;
			$foundPID = $2;
		} else {
			print STDERR "Could not find vgetty running on line $line\n";
			exit(1);
		}
	}
	
	
	my $signaled = kill $Signal, $foundPID;
	unless ($signaled)
	{
		print STDERR "kill $Signal, $foundPID returned $signaled processes signaled\n";
		exit(2);
	}
	exit(0);

}
