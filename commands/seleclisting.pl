#!/usr/bin/perl -w

=head1 seleclisting.pl

=head1 NAME

seleclisting.pl - Default program to provide selection listings within VOCP command shells

=head1 DESCRIPTION

This program must reside beneath the commanddir and cmdshell_list must point to it
(both set in the vocp.conf file).  The cmdshell_list_key (9 by default), when entered in a command shell,
will run this program and convert its output using text-to-speech providing a nice directory of available selections.

=head1 AUTHOR INFORMATION

LICENSE

    seleclisting.pl, part of the VOCP voice messaging system.
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

use VOCP;
use VOCP::Util;

use strict;

use vars qw{
		$Vocp
		$TmpDir
		$Debug
	};

$Debug = 0; # set to 0 for minimal debug output, 1 for some and 2 for verbose


{

	# Get and validate the box number from the argument list
	my $boxnum = shift @ARGV;
	
	unless (defined $boxnum && $boxnum =~ m|^(\d+)$|)
	{
		error("Must pass a valid box number to seleclisting dot P.L.");
	}
	$boxnum = $1;
	
	
	# Create a new VOCP object, to parse the box conf and provide access to the data
	my $options = {
		'genconfig'	=> $VOCP::Vars::Defaults{'genconfig'},
		'boxconfig'	=> '',
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1, # no need for logging here...
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck
		
		};
	
	$Vocp = VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP object");
	
	# This probably has no impact but it is nice to switch into a safe temp dir no matter what we do.
	$TmpDir = $Vocp->{'tempdir'} || $VOCP::Vars::Defaults{'tempdir'} || '/tmp';
	unless (-w  $TmpDir)
	{
		print STDERR "Can't write to $TmpDir\n"
			if ($Debug);
		
		$TmpDir =  (getpwuid($>))[7] ;
		
		unless ( -w $TmpDir)
		{
			print STDERR "Can't write to $TmpDir either.\n";
		}
	}
	chdir($TmpDir);
	
	# Validate that this is a command shell box
	my $boxType = $Vocp->type($boxnum);
	
	unless ($boxType)
	{
		error("Invalid box number '$boxnum' passed to seleclisting dot P.L");
	}
	
	unless ($boxType eq 'command')
	{	
		error("Box number '$boxnum' is not a command shell, it is a $boxType box");
	}
	
	
	# Get an array ref of available selections.
	my $selections = $Vocp->get_box_commands_list($boxnum, 'UNTAINT');
	
	unless ($selections)
	{
		error("Box number '$boxnum' returned no available selections.");
	}
	
	
	# Format an output string for the TTS.
	my $output = "The following selections are available in box $boxnum.\n";
	
	foreach my $sel ( sort {$a->{'selection'} cmp $b->{'selection'} } @{$selections})
	{
		my $line = "Enter " . $sel->{'selection'} . " to run " . $sel->{'run'};
		if ($sel->{'input'} && $sel->{'input'} ne 'none')
		{
			$line .= " with " . $sel->{'input'} . " input ...\n";
		} else {
			$line .= "...\n";
		}
		$output .= $line;
	}
	
	
	# All we need to do now is print it out, VOCP handles the rest.
	print $output ;
	
	exit(0);
}


# Errors are logged (if STDERR is redirected) and output to the caller
sub error {
	my $errMsg = shift;
	
	VOCP::Util::log_msg($errMsg);
	
	print "$errMsg\n";
	
	exit(1);
}
