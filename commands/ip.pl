#!/usr/bin/perl

=head2 ip.pl - example for VOCP command shells

Copyright (C) Pat Deegan 2000
Distributed as part of the VOCP system, under the terms of 
the GNU GPL, see the LICENSE file.

Outputs each portion of the requested interfaces IP, on 
seperate lines.

When used from a command shell, if the input is set to 'text'
the caller will be asked for input before running the script.

If the caller enters '71 71 71 00', this will be translated
to 'ppp0' and he/she will hear the current ip of that interface
(quite usefull for finding your ADSL-connected machine).

See the docs or the website (http://www.VOCPsystem.com) for
info on entering text through a phone's dialpad.

Make sure the commands return type is set to 'output' to hear the ip.

Will say 'ninety-nine' if no IP was found for the requested
interface.

=cut


use strict;

# Outputs the ip of either the interface passed on the command line, 
# or eth0.
#
# in the case where no ip is found for the interface, ouptuts '99'


my $if = shift || 'eth0';

{
	my $ip = getip($if);

	my @num = split('\.', $ip);

	foreach my $num (@num) {
		print "$num\n";
	}

	exit(2);
}



################### getip ############################
# getip IF
#  where IF is the interface (usually ppp0) to 
#  monitor.
# getip uses ifconfig and a little pattern matching to
# extract the current inet addr.  If the interface is
# down, getip returns 'unavailable' or else it
# returns the dotted quad ip.
######################################################
sub getip {

	my $if = shift 
		|| die "Must provide an interface to getip!";

	my $found = 0;
	
        my $ipad = `/sbin/ifconfig $if | grep \'inet addr\'`;
        my @info = split(/ /, $ipad);
        foreach (@info) {
                $ipad = $_ if (/^addr:*/);
		$found++;
        }
 
        if ($found) {
	
		$ipad = substr($ipad,5,16);
		
	} else {
	
		$ipad = "99";
	}
	
	return $ipad; 
	
}
