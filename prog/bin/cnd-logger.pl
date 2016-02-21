#!/usr/bin/perl

=head1 cnd-logger.pl

=head2 NAME

cnd-logger.pl - Caller ID info logger

=head2 DESCRIPTION

This program is meant to be run by mgetty, BEFORE the call is answered, such that you can see
caller id information and pickup before VOCP does so.

It is configured in the mgetty.config file with a line like:

cnd-program /usr/local/vocp/bin/cnd-logger.pl

When the program is called by mgetty, it is called like so:
  
  <program> <tty> <CallerID> <Name> <dist-ring-nr.> <Called Nr.>

The cnd-program exit status is used by mgetty to determine whether to allow the call or not.
exit(0) - proceed
exit(1) - dissallow

For the moment we aren't using this functionality but it may be interesting to look into.  

On the other hand, you might want to look into VOCP's cid-filter functions as well.


=head1 AUTHOR INFORMATION

LICENSE

    VOCP CND Logger, part of the VOCP voice messaging system.
    Copyright (C) 2002 Patrick Deegan
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


use VOCP::Vars;
use VOCP::Util;
use VOCP::Util::CallMonitor;

use vars qw{

		$Debug
	};
	
$Debug = 0;

my $logfile = $VOCP::Vars::Defaults{'calllog'};

my @Args = ('tty', 'callerid', 'callername', 'dist-ring', 'callednum');

unless (scalar @ARGV == scalar @Args)
{
	print STDERR "Strange - num args does not match num expected "
			. scalar @ARGV . '!=' .scalar @Args;
}

my %CallValues;
foreach my $argument (@Args)
{
	$CallValues{$argument} = shift @ARGV;
	print STDERR "Got a value of " . $CallValues{$argument}  . " for $argument \n"
		if ($Debug);
	
}

{

	my $callLogger = VOCP::Util::CallMonitor::Logger->new( { 'logfile'	=> $logfile})
					|| return VOCP::Util::error("Could not create new CallMonitor::Logger object");
					
		
		
	$callLogger->newMessage ( {
					'type'	=> $VOCP::Util::CallMonitor::Message::Type{'INCOMING'},
					'cid'	=> $CallValues{'callerid'},
					'cname'	=> $CallValues{'callername'},
					'called' => $CallValues{'callednum'},
				});
		
	$callLogger->logMessage();
	
	exit(0);
}
	
	
	
		
