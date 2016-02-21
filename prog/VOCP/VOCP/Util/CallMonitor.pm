package VOCP::Util::CallMonitor;

use FileHandle;
use VOCP::Vars;
use VOCP::Strings;

use strict;

use vars qw {
		$ContinueMonitoring
		$VERSION
	};
	
$VERSION = $VOCP::Vars::VERSION;

=head1 VOCP::Util::CallMonitor

=head2 NAME 

VOCP::Util::CallMonitor - monitor incoming calls, mainly for caller ID info.


=head2 SYNOPSIS

The VOCP::Util::CallMonitor class allows you to write programs that do interesting
stuff when a call comes in.  Example use:


	use VOCP::Util::CallMonitor;
	
	my $options = {
			'logfile'   => '/var/log/vocp-calls.log',
			'sleeptime' => 1,
		};
	
	my $callMon = VOCP::Util::CallMonitor->new($options);
	
	$callMon->startMonitoring();
	
	while ($Continue)
	{
		if ($callMon->dataWaiting())
		{
			my ($callCount, $type, $infoString, 
					$rawData) = $callMon->getData();
			
			# Do stuff
		} else {
			# Do other stuff 
			# ...
			# or just
			sleep(1);
		}
	}
	
	$callMon->stopMonitoring();
	
	exit(0);
	

=head2 DESCRIPTION

This class encapsulates the grunt work needed to monitor changes to the VOCP call log file.  When the 
startMonitoring() method is called, the object forks the process spawning a child that will periodically
examine the logfile for new incoming calls.  When new call data is found, it is queued for output - the call
to dataWaiting() will then return TRUE and the data may be extracted using getData().  What you do with 
the call data is up to you and we will not be held responsible ;)


=head1 AUTHOR

LICENSE

    VOCP::Util::CallMonitor module, part of the VOCP voice messaging system package.
    Copyright (C) 2002 Patrick Deegan
    All rights reserved
    
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


Official VOCP site: http://VOCPsystem.com

Contact page for author available in contact section at 
http://www.psychogenic.com/



=head2 new [OPTIONSHREF]

Creates a new instance of the class.  key/value pairs in OPTIONSHREF (if passed)
are stored within the object.


=cut
		


sub new {
	my $class = shift;
	my $options = shift;
	
	my $self = {
			'logfile'	=> $VOCP::Vars::Defaults{'calllog'},
			'sleeptime'	=> 1,
		};
        
        bless $self, ref $class || $class;
	
	$self->init($options);
	
	return $self;
}


sub init {
	my $self = shift;
	my $options = shift;
	
	return undef unless ($options);
	
	while (my ($key, $val) = each %{$options})
	{
		$self->{$key} = $val;
	}
}



sub logfile {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{
		$self->{'logfile'} = $setTo;
	}
	
	return $self->{'logfile'} ;
	
}


=head2 startMonitoring

Spawns a child that will periodically examine the logfile for new calls. Returns immediately.

=cut


sub startMonitoring {
	my $self = shift;
	
	
	my ($readFh, $writeFh) = FileHandle::pipe;
	$readFh->autoflush();
	$writeFh->autoflush();
	
	$self->{'_readbits'} = '';
	vec($self->{'_readbits'}, $readFh->fileno(), 1) = 1;
	
	$self->{'_readFh'} = $readFh;
	$self->{'_writeFh'} = $writeFh;
	
	$ContinueMonitoring = 1;
	my $child = fork();
	if ($child)
	{
		# in parent
		close($writeFh);
		#$SIG{CHLD} = \&REAPER unless ($SIG{CHLD});
		$self->{'_childpid'} = $child;
		
	} else {
		
		sleep(1);
		close($readFh);
		$self->doTail();
		exit(0);
	}
}


=head2 stopMonitoring

Let the child process know that we are done.  Stops monitoring logfile.

=cut

sub stopMonitoring {
	my $self = shift;
	
	$ContinueMonitoring = 0;
	my $child = $self->{'_childpid'};
	if ($child)
	{
		kill 12, $child;
	}
}

=head2 dataWaiting

Will return a TRUE value if there is data concerning a new incoming call, in the queue - undef otherwise.

=cut

sub dataWaiting {
	my $self = shift;
	
	my $rbits;
	
	my $nfound = select($rbits = $self->{'_readbits'},undef,undef,0.1); 
	
	return undef if ($nfound == 0);
	
	return 1;
}


=head2 getData

Reads incoming call data from the queue, returning an array composed of (COUNT, INFOSTR, RAW) where:

COUNT is the call count since the start of monitoring.

INFOSTR is an informational string of the form "Incoming call from 514-555-1212 Pat Deegan"

RAW is the raw data as found in the logfile.


NOTE: This call will block if there is no dataWaiting().

=cut

sub getData {
	my $self = shift;
	my $readFh = $self->{'_readFh'} || return undef;
	
	my ($size, $text);
	sysread($readFh, $size, 5);
	unless ($size && $size =~ m|^(\d+)\s*$|)
	{
		return undef;
	}
	$size = $1;
	#chomp($size);
	
	sysread($readFh, $text, $size);
	
	
	my ($count, $type, $label, $raw) = split(/\|/, $text, 4);
	chomp($label);
	
	print STDERR "getData got $count '$label' ($raw) from '$text'\n" if ($main::Debug);
	
	return ($count, $type, $label, $raw);
}


# TAILSTOP called on kill USR2 from parent to child
sub TAILSTOP {
	
	$ContinueMonitoring = 0;
};

# doTail
# Actually checks the logfile, sending info to the parent when found,
# sleeping sleeptime otherwise
sub doTail {
	my $self = shift;
	
	$SIG{USR2} = \&TAILSTOP;
	
	my $filename = $self->{'logfile'};
	
	my $sleeptime = $self->{'sleeptime'} || 1;
	
	my $writeFh = $self->{'_writeFh'};
	
	$self->{'readHandle'} = FileHandle->new();
	
	$self->{'readHandle'}->open("<$filename");
	
	$self->{'readHandle'}->seek(0,2); # Go to end
	
	my $callCount = 0;
	my $newMsgCount = 0;
	while ($ContinueMonitoring)
	{
		$self->{'readHandle'}->seek(0,1); # Don't move, reset EOF flag
		
		my $line = $self->{'readHandle'}->getline();
		unless ($line)
		{
			sleep($sleeptime);
			next;
		}
		chomp($line);
		
		print STDERR "CallMonitor::doTail() got '$line'\n" if ($main::Debug);
		
		my $logMessage = VOCP::Util::CallMonitor::Message->new($line);
		
		my $str;
		if ($logMessage->{'type'} eq $VOCP::Util::CallMonitor::Message::Type{'INCOMING'})
		{
			$callCount++;
			
			$str = "$callCount|$VOCP::Util::CallMonitor::Message::Type{'INCOMING'}|"
				. $VOCP::Strings::Strings{$VOCP::Vars::Defaults{'language'}}{'incomingcall'};
			if ($logMessage->{'cid'} || $logMessage->{'cname'})
			{
				$str .= ' ' . $VOCP::Strings::Strings{$VOCP::Vars::Defaults{'language'}}{'from'} . ' ';
				$str .= $logMessage->{'cid'} if ($logMessage->{'cid'});
				$str .= ' ' .  $logMessage->{'cname'} if ($logMessage->{'cname'});
			}
			
			if ($logMessage->{'called'} =~ /[\d\w]+/)
			{
				$str .= "Called: '$logMessage->{'called'}'";
			}
			
		} elsif ($logMessage->{'type'} eq $VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'})
		{
			$newMsgCount++;
			$str = "$callCount|$VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'}|"
			. $VOCP::Strings::Strings{$VOCP::Vars::Defaults{'language'}}{'newmessage'} 
			. $logMessage->{'boxnum'};
		} else {
			VOCP::Util::log_msg("Unrecognized type '$logMessage->{'type'}' - skipping.");
			next;
		}
			
		
		$str .= '|' . $logMessage->toString();
		
		my $size = length($str) ; # + 1; # string length + the \n
		if ($size < 10) {
			$size = "000$size";
		} elsif ($size < 100)
		{
			$size = "00$size";
		} elsif ($size < 1000)
		{
			$size= "0$size";
		} elsif ($size > 10000)
		{
			die "Ugh invalid size '$size'";
		}
	
		print $writeFh "$size\n";
		print $writeFh "$str\n";
		
		
	}
	$self->{'readHandle'}->close();
	$writeFh->close();
	
	print STDERR "Out of child tail loop\n" if ($main::Debug);
	
	
}




# The REAPER is needed to collect dead children, lest they turn to zombies
sub REAPER {
               my $waitedpid = wait;
               # loathe sysV: it makes us not only reinstate
               # the handler, but place it after the wait
	       print STDERR "The REAPER has got you, $waitedpid!" if ($main::Debug);
               $SIG{CHLD} = \&REAPER;
}


# Make sure the spawned child exits
sub DESTROY {
	my $self = shift;
	
	$self->stopMonitoring();
	
}

package VOCP::Util::CallMonitor::Message;

use strict;

use vars qw{
		%Type
	};
	
%VOCP::Util::CallMonitor::Message::Type = (
			'INCOMING'	=> 'incoming call',
			'NEWMESSAGE'	=> 'new message',
		);


sub new {
	my $class = shift;
	my $init = shift;
	
	my $self = {};
        bless $self, ref $class || $class;
	
	$self->init($init);
	
	return $self;
}


sub init {
	my $self = shift;
	my $options = shift;
	
	return undef unless ($options);
	
	if (ref $options eq 'HASH')
	{
		while (my ($key, $val) = each %{$options})
		{
			$self->{$key} = $val unless ($key =~ m|^_|);
		}
		
		unless ($self->{'time'})
		{
			
			$self->{'time'} = time();
			$self->{'datestring'} = scalar localtime($self->{'time'});
		}
		
	} else {
		
		my ($time, $type, $dateString, @rest) = split('\|', $options);
		
		$self->{'datestring'} = $dateString;
		$self->{'time'} = $time;
		$self->{'type'} = $type;
		
		if ($type eq $VOCP::Util::CallMonitor::Message::Type{'INCOMING'})
		{
			$self->_incomingSetup(@rest);
		} elsif ($type eq $VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'})
		{
			$self->_msgleftSetup(@rest);
		} else {
			return VOCP::Util::error("VOCP::Util::CallMonitor::Message::new() Invalid type '$type' passed to init");
		}
	}
	
}

sub _incomingSetup {
	my $self = shift;
	my $cid = shift || '';
	my $cname = shift || '';
	my $called = shift || '';
	
	
	$self->{'cid'} = $cid;
	$self->{'cname'} = $cname;
	$self->{'called'} = $called;
	chomp($self->{'called'});
	
}


sub _msgleftSetup {
	my $self = shift;
	my $boxnum = shift || return VOCP::Util::error("VOCP::Util::CallMonitor::Message::new() Must pass a box number to setup.");
	
	$self->{'boxnum'} = $boxnum;
	chomp($self->{'boxnum'});
}



sub toString {
	my $self = shift;
	
	my $type = $self->{'type'};
	
	if ($type eq $VOCP::Util::CallMonitor::Message::Type{'INCOMING'})
	{
		return $self->_incomingtoString();
	} elsif ($type eq $VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'})
	{
		return $self->_msglefttoString();
	} else {
		return VOCP::Util::error("VOCP::Util::CallMonitor::Message::toString() Invalid type '$type'.");
	}
}


sub _incomingtoString {
	my $self = shift;
	
	my @params = ($self->{'time'}, $self->{'type'}, $self->{'datestring'}, $self->{'cid'}, $self->{'cname'}, $self->{'called'});
	
	my $retStr = join('|', @params);
	
	return $retStr;
}

sub _msglefttoString {
	my $self = shift;
	
	my @params = ($self->{'time'}, $self->{'type'}, $self->{'datestring'}, $self->{'boxnum'});
	
	my $retStr = join('|', @params);
	
	return $retStr;
}


	

package VOCP::Util::CallMonitor::Logger;

use FileHandle;

use strict;

sub new {
	my $class = shift;
	my $init = shift;
	
	
	my $self = {
			'logfile'	=> $VOCP::Vars::Defaults{'calllog'},
		};
		
        bless $self, ref $class || $class;
	
	$self->init($init);
	
	return $self;
}


sub init {
	my $self = shift;
	my $options = shift;
	
	return undef unless ($options);
	
	while (my ($key, $val) = each %{$options})
	{
		$self->{$key} = $val unless ($key =~ m|^_|);
	}
	
}


sub newMessage {
	my $self = shift;
	my $params = shift;
	
	my $newMessage = VOCP::Util::CallMonitor::Message->new($params);
	
	$self->{'_lastMessage'} = $newMessage;
	
	return $newMessage;
}

sub logMessage {
	my $self = shift;
	my $message = shift || $self->{'_lastMessage'} 
		|| return VOCP::Util::error("VOCP::Util::CallMonitor::Logger::logMessage Must pass a message in or use newMessage");
		
	
	my $str = $message->toString();
	
	unless ($self->{'_openLogFile'})
	{
	
	
		return VOCP::Util::error("VOCP::Util::CallMonitor::Logger::logMessage Must have a logfile set")
			unless ($self->{'logfile'});
			
		$self->{'_openLogFile'} = FileHandle->new();
		
		unless ($self->{'_openLogFile'}->open($self->{'logfile'}, O_WRONLY|O_APPEND|O_CREAT))
		{
			
			VOCP::Util::log_msg("VOCP::Util::CallMonitor::Logger::logMessage Could not open "
							. "$self->{'logfile'} for write $! Skipping");
			delete $self->{'_openLogFile'};
			return ;
		}
		$self->{'_openLogFile'}->autoflush();
		
	}
	
	$self->{'_openLogFile'}->print("$str\n");
}

sub shutdown {
	my $self = shift;
	
	if ($self->{'_openLogFile'})
	{
		$self->{'_openLogFile'}->close();
		delete $self->{'_openLogFile'};
	}
	
}


sub DESTROY {
	my $self = shift;
	
	$self->shutdown();
}

		
		
		



1;
