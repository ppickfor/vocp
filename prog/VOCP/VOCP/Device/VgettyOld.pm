package VOCP::Device::VgettyOld;
 
use base qw (VOCP::Device);
use VOCP::Util;
use VOCP::Vars;

use strict;

=head1 NAME

VOCP::Device::VgettyOld - old code driving the vgetty device. Included for reference,
consider DEPRECATED.

=head1 AUTHOR

LICENSE

    VOCP::Device::VgettyOld module, part of the VOCP voice messaging system package.
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


=cut

use vars qw {
		$DeviceDefined
		$VERSION 
	};

$VERSION = $VOCP::Vars::VERSION;
$DeviceDefined = 1;


my %Vgetty = (
	'READY' 	=> 'READY',
	'HELLOSH' 	=> 'HELLO SHELL',
	'PLAY'		=> 'PLAY',
	'PLAYING' 	=> 'PLAYING',
	'RECORD'	=> 'RECORD',
	'RECORDING'	=> 'RECORDING',
	'WAIT'		=> 'WAIT',
	'WAITING'	=> 'WAITING',
	'BEEPING'	=> 'BEEPING',
	'STOP'		=> 'STOP',
	'ERROR'		=> 'ERROR',
	'DIAL'		=> 'DIAL',
	'DIALING'	=> 'DIALING',
	'GOODBYESH'	=> 'GOODBYE SHELL',
	'NOVOICE'	=> 'NO_VOICE_ENERGY',
	'SILENCE'	=> 'SILENCE_DETECTED',
	'DTMF'		=> 'RECEIVED_DTMF',
	'DATA'		=> 'DATA_CALLING_TONE',
	'FAX'		=> 'FAX_CALLING_TONE',
	'DATAORFAX'	=> 'DATA_OR_FAX_DETECTED',
	'SENDFAX'	=> 'SENDFAX',
	# TIMEOUT is not a vgetty cmd/resp - used
	# for Read() with timeout
	'TIMEOUT'	=> 'TIMEOUT',
	);



sub init {
	my $self = shift;
	my $params = shift;

	return 1;
	
}


=head2 connect

Connects to vgetty and prepares it for our commands.

Note for DEVELOPPERS: Setting 
'DEVICE' => 'INTERNAL_SPEAKER' as an option in your call
to new() will facilitate debugging as all messages will
be played on the (yeah, I know, not-so-great) modem\'s 
internal speaker.

=cut

sub connect {
	my $self = shift;
	my $params = shift;
	
	VOCP::Util::log_msg("Connecting to vgetty")
		if $main::Debug;
	
	$self->send_and_receive("", $Vgetty{'HELLOSH'});
	$self->send_and_receive("HELLO VOICE PROGRAM", $Vgetty{'READY'});
	$self->send_and_receive("ENABLE EVENTS", $Vgetty{'READY'});
	$self->send_and_receive("AUTOSTOP OFF", $Vgetty{'READY'});
	
	my $device = $params->{'device'} || $self->{'device'};
	if ($device) { 
		# Debugging trick:
		# call new with 'DEVICE' => 'INTERNAL_SPEAKER' 
		# to use the vm shell.
		VOCP::Util::log_msg("Using DEVICE: $self->{'device'}")
			if ($main::Debug);
		
		$self->send_and_receive("DEVICE $self->{'device'}", $Vgetty{'READY'});
	}
	
	$self->{'isconnected'} = 1;	
	
	return 1;
}




=head2 diconnect
	
Politely diconnects from vgetty by sending a GOODBYE command.
Use this when your program is done.

=cut

sub disconnect {
	my $self = shift;
	my $params = shift;
	
	
	return 0 unless ($self->{'isconnected'});
	
	VOCP::Util::log_msg("Disconnecting from vgetty")
		if $main::Debug;
	
	$self->send_and_receive("GOODBYE", $Vgetty{'GOODBYESH'});
	
	$self->{'isconnected'} = 0;
	
	return 1;
}


=head2 beep FREQUENCY LENGTH

Sends a beep through the chosen device using given frequency (HZ) and length (in miliseconds).  Returns a defined
and true value on success.

=cut

sub beep {
	my $self = shift;
	my $frequency = shift;
	my $length = shift;
	
	# Beep
	if ($frequency && $length)
	{
		$self->Write("BEEP $frequency $length");
	} else {
		$self->Write("BEEP");
	}
	
	my $resp = $self->Read();
	while ($resp eq $Vgetty{'BEEPING'}) {
		$resp = $self->Read();
	}
	
	return 1 if ($resp);
	
	return 0;
}



=head2 dial DESTINATION

Connects to destination.  Returns defined & true on success.

=cut

sub dial {
	my $self = shift;
	my $destination = shift;
	
	
	VOCP::Util::error("Must pass a number to dial!", $VOCP::Vars::Exit{'MISSING'})
		unless $destination;
		
	VOCP::Util::error("Invalid phone number passed to VOCP::VgettyOld::dial() '$destination'")
		unless ($destination =~ /^[\dABCD\*#]+$/);

	$self->send_and_receive("$Vgetty{'DIAL'} $destination", $Vgetty{'DIALING'});
	
	my $resp = $self->Read();
	while ($resp ne $Vgetty{'DIALING'}) {
		sleep 1;
		$resp = $self->Read();
	}
	
	VOCP::Util::log_msg("Dialed $destination succesfully");
	
	return 1;
	
}


=head2 play PLAYPARAM

plays a sound (file, text-to-speech, whatever is appropriate) base on PLAYPARAM.  May or may not block during
play depending on device implementation.  Returns true on success.

=cut

sub play {
	my $self = shift;
	my $msg = shift;
	my $type = shift;
	
	
	if ($msg) {
		VOCP::Util::error("VOCP::play really needs absolute paths", $VOCP::Vars::Exit{'MISSING'})
			unless ($msg =~ m|^/|);
	} else {
		VOCP::Util::error("Pass a file to VOCP::play!", $VOCP::Vars::Exit{'MISSING'});
	}
	
	# Make sure we can read the msg
	VOCP::Util::error("$msg either does not exist or is unreadable", $VOCP::Vars::Exit{'FILE'})
		unless (-r $msg);
	
	VOCP::Util::log_msg("Playing message")
		if ($main::Debug);
	
	$self->stop_and_empty(); #Just in case we're already doing something...
	
	$self->Write("$Vgetty{'PLAY'} $msg");
	
	my $resp = $self->Read();
	while ($resp eq $Vgetty{'PLAYING'}) {
		$resp = $self->Read();
	}
	
	return 1;
}


=head2 record TOFILE

Records input from user to device to file TOFILE.  Returns true on success.

=cut

sub record {
	my $self = shift;
	my $tofile = shift;
	
	my $resp = $self->recordFile($tofile);
	
	return 1 if ($resp);
	
	return 0;
}


=head2 wait TIME

Simply waits for TIME seconds.  Device should accept/queue user input 
during interval.

=cut

sub wait {
	my $self = shift;
	my $time = shift;
	
	$self->Write("WAIT $time");
	$self->waitFor("READY");
	
	return 1;
}


=head2 waitFor STATE

Waits until STATE is reached/returned by device.  Device should accept/queue user input 
during interval.

=cut

sub waitFor {
	my $self = shift;
	my $state = shift;
	
	my $gotState = $self->Read();
	
	while ($gotState ne $state)
	{
		$gotState = $self->Read();
	}
	
	return 1;
}

=head2 stop

Immediately stop any current activity (wait, play, record, etc.).

=cut
sub stop {
	my $self = shift;
	
	
	print STDERR "VOCP::Device::stop() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}

=head2 blocking_play PLAYTHIS

play PLAYTHIS and return only when done.

=cut

sub blockingPlay {
	my $self = shift;
	my $msg = shift;
	my $type = shift;
	
	
	if ($msg) {
		VOCP::Util::error("VOCP::Device::VgettyOld::play really needs absolute paths", $VOCP::Vars::Exit{'MISSING'})
			unless ($msg =~ m|^/|);
	} else {
		VOCP::Util::error("Pass a file to VOCP::Device::VgettyOld::play!", $VOCP::Vars::Exit{'MISSING'});
	}
	
	# Make sure we can read the msg
	VOCP::Util::error("$msg either does not exist or is unreadable", $VOCP::Vars::Exit{'FILE'})
		unless (-r $msg);
	
	VOCP::Util::log_msg("Playing message")
		if ($main::Debug);
	
	$self->stop_and_empty(); #Just in case we're already doing something...
	
	$self->Write("$Vgetty{'PLAY'} $msg");
	
	my $resp = $self->Read();
	while ($resp eq $Vgetty{'PLAYING'}) {
		$resp = $self->Read();
	}
	
	return 1;
}





=head2 readnum PLAYTHIS TIMEOUT [REPEATTIMES]

Plays the PLAYTHIS and then waits for the sequence of the digit input finished. If no are entered within TIMEOUT 
seconds, it re-plays the message again. It returns failure (undefined value) if no digits are entered after the message
has been played REPEATTIMES (defaults to 3) times. 


It returns a string (a sequence of DTMF tones 0-9,A-D and `*') without the final stop key (normally '#'). 


=cut


sub readnum {
	my $self = shift;
	my $playthis = shift;
	my $timeout = shift;
	my $repeatTimes = shift || 3;
	
	
	print STDERR "VOCP::Device::beep() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}



sub sendImage {
	my $self = shift;
	my $file = shift;
	
	$self->Write("$Vgetty{'SENDFAX'} $file");
	
	my $resp = $self->Read();
	VOCP::Util::log_msg("VOCP SENDFAX said: '$resp'")
		if ($main::Debug || $resp ne 'HUP_CODE');
		
	return 1;
}





=head2 validDataFormats 

Returns an array ref of valid data formats (eg 'rmd', 'wav', 'au') the device will accept.

=cut

sub validDataFormats {
	my $self = shift;
	
	my @validFormats = ('rmd');
	
	return \@validFormats;
}



############### End interface, begin module specific privates #####################


=head1

	##### Talking to vgetty #####


=head2 send_and_receive SEND RECEIVE [NOERROR]

Funtion used to Write() SEND to vgetty.  The response returned by 
vgetty is Read() in and compared to RECEIVE.  

If they are unequal, the program exits with a VOCP::Util::error() messages,
unless the optional NOERROR is set to true.

Returns the actual vgetty response.

=cut

sub send_and_receive {
	my $self = shift;
	my $send = shift;
	my $receive = shift;
	my $noerror = shift; # optional
	
	my $resp;
	if ($send ne "") {
		$self->Write($send);
	}
	$resp = $self->Read();
	if ($resp ne $receive) {
		VOCP::Util::error(qq|Sent "$send". Expected "$receive". Got "$resp".|, , $VOCP::Vars::Exit{'VGETTY'})
			unless ($noerror);
	}
	
	return $resp;
}





=head2 event RESP

General handler for vgetty RESPonses.

If vgetty is indicating that it has received DTMF, the sequence 
is extracted with get_dtmf() and returned.

If it is a dtmf digit, it is returned.

If it is a tone (fax or data call), the program exits with the
appropriate code.

If vgetty is simply saying it is ready, the message is returned.

Else the program dies because of the unexpected input - code better!

=cut

sub event {
	my $self = shift;
	my $resp = shift
		|| return undef;

	if ($resp eq $Vgetty{'READY'}) { #We're done playing/recording/waiting
	
		#we may proceed normaly
		return $Vgetty{'READY'};
		
	} elsif ($resp eq $Vgetty{'DTMF'}) { # User is impatient!
		
		# Commented out -- do NOTHING!!
		
		# Get the tones
		#return $self->get_dtmf();
		
	} elsif (my $tone = VOCP::Device::VgettyOld::is_tone($resp)) { # Got some sort of tone
	
		VOCP::Util::log_msg("Got a tone ($tone), exiting");
		
		exit($tone);
		
		
	} elsif ( $resp =~ /[\d#\*]+/ ) {
		# got a dtmf something
		
		VOCP::Util::log_msg("Got a dtmf tone ($resp) while looking for events... returning it")
			if ($main::Debug);
		return $resp;
				
	} else { # Got something unexpected
		VOCP::Util::log_msg(qq|Events: Expecting "$Vgetty{'READY'}" got "$resp"|)
			if ($main::Debug);
			
		return $resp;
	}
	
}


=head2 Stop [NOERROR]

Sends a STOP signal to vgetty, so that it will stop playing/recording/
waiting...

Calls send_and_receive() passing it NOERROR, such that responses other
than READY will not cause the program to die.

Returns the actual vgetty response.

=cut

sub Stop {
	my $self = shift;
	my $noerror = shift;
	
	return $self->send_and_receive($Vgetty{'STOP'},$Vgetty{'READY'}, $noerror );
	
}


=head2 stop_and_empty 

Used when you wish to send vgetty a stop and no longer 
care about what is in the buffer.  Usefull in cases where
it is important to stop the current action, but use
parcimoniously - it is better to keep control of the 
contents of the buffer!

stop_and_empty() sends the signal and flushes the buffer.
Calls Read() with a timeout of 2 seconds, to make sure we
do not hang.

Returns the final response from vgetty.

=cut

sub stop_and_empty {
	my $self = shift;
	
	my $resp = "";
	
	VOCP::Util::log_msg("Sending stop and flushing queue")
		if ($main::Debug);
	
	$self->Write($Vgetty{'STOP'});
	# Empty any extra junk from queue
	while($resp ne $Vgetty{'TIMEOUT'} && $resp ne $Vgetty{'READY'}
		&& $resp ne $Vgetty{'ERROR'}) {
		
		$resp = $self->Read(2);
		
		VOCP::Util::log_msg("Dumping vgetty response, $resp")
			if ($main::Debug > 1);
			
	}
	
	return $resp;
}


sub recordFile {
	my $self = shift;
	my $file = shift;
	
	$self->Write("$Vgetty{'RECORD'} $file");
	
	my $resp = $self->Read();
	while ($resp eq $Vgetty{'RECORDING'}) {
		$resp = $self->Read();
		
	}
	
	# If we got dtmf, stop as quickly as 
	# possible and flush the tones
	if ($resp eq $Vgetty{'DTMF'}) {
		
		return $self->stop_and_empty();
		
	} else { # Deal with events (e.g. fax tone)...
	
		$self->event($resp)
			unless ( ($resp eq $Vgetty{'READY'}) 	 # All done
			|| ($resp eq $Vgetty{'NOVOICE'}) # Was voice, now none
			|| ($resp eq $Vgetty{'SILENCE'}) # No sound
			); 
			
	}
	
	
	return $resp;
	
}



=head2 Read [TIMEOUT]

Returns the message read from vgetty.

In certain cases, it is best to set a TIMEOUT value.  If nothing
is received from vgetty within TIMEOUT, READY is returned.

=cut

sub Read {
	my $self = shift;
	my $timeout = shift; #optional
		
	my $resp;
	
	if ($timeout) {
		# We want to avoid hanging here, waiting for something to
		# happen, set a alarm in an eval...
		eval {
			local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
			alarm ($timeout);
			$resp = `read -r INPUT <&\$VOICE_INPUT;echo \$INPUT`;
			chop ($resp);
			alarm 0;
		};
		if ($@) { #We timed out
			VOCP::Util::log_msg("Read() timed out.  Returning TIMEOUT")
				if ($main::Debug);
	
			return $Vgetty{'TIMEOUT'};
		}
		
	} else { # Normal read
	
		$resp = `read -r INPUT <&\$VOICE_INPUT;echo \$INPUT`;
		chop ($resp);
	}
		
	VOCP::Util::log_msg(qq|Got "$resp"|)
		if ($main::Debug > 1);
	return $resp;
}

=head2 Write MSG

Write MSG to vgetty.  MSG is not validated, make sure you
send good stuff...

=cut

sub Write {
	my $self = shift;
	my $message = shift;
	
	system ("echo $message >&\$VOICE_OUTPUT");
	system ("kill -PIPE \$VOICE_PID");
	VOCP::Util::log_msg(qq|Sent "$message"|)
		if ($main::Debug > 1);
}



=head2 get_dtmf [WAIT]

Gets and returns a user\'s DTMF input.  If INPUT is passed (a key may
have been pressed during playing of a message, so as not to loose it
play() will return it and we pass it to get_dtmf()), it is used as the
first key received by get_dtmf().

The method will wait for WAIT seconds if set or 'pause' seconds (set in 
genconfig file or with call to new()) for user input.

Pressing the pound sign ('#') at any time will abort DTMF collection
and return previously pressed keys immediately.

Returns the keys pressed by user (minus the '#', if pressed).

Note for DEVELOPPERS:  If the global variable $Debug is true AND the 
global $Fake_DTMF is also set in the driver program (main), this will
simulate user input.  This is very usefull when debugging, as you can
simulate a sequence of user key presses by redefining Fake_DTMF in 
your code.

=cut


# This is the funkiest function, but after a lot of tweaking,
# it manages to work quite well - Be sure to leave 
# AUTOSTOP OFF in the connect() sub.
sub get_dtmf {
	my $self = shift;
	my $wait = shift; #optionaly sets time to wait for user
	
	VOCP::Util::log_msg("Getting DTMF tones.")
		if ($main::Debug);

	# If we are debugging AND Fake_DTMF is set in main
	# we pretend we got $Fake_DTMF from input
	if ($main::Debug && $main::Fake_DTMF) {
	
		VOCP::Util::log_msg("Got **FAKE** DTMF: ".$main::Fake_DTMF );
	
		return $main::Fake_DTMF;
	}
	
	my $input; #Get rid of anything non-dtmf
	
	#empty the queue first
	my $done;
	my $resp = "";
	
	while ($resp ne $Vgetty{'TIMEOUT'} && !$done) {
	
		# Read with a short timeout, after a lot of testing
		# 3 seconds seems to be the best to avoid false timeouts
		$resp = $self->Read('3');

		if ($resp eq $Vgetty{'DTMF'}) { # Next is dtmf
		
			# Fetch the dtmf
			next;

		} elsif ($resp =~ /[\d#\*]/) { # This is dtmf
		
			if ($resp eq '#') { #done
			
				VOCP::Util::log_msg("Got input '#' from queue")
					if ($main::Debug > 1);

				$self->stop_and_empty();
				
				$done++;
			} else { # some valid input
				$input .= $resp;
				
				VOCP::Util::log_msg("Got input '$resp' from queue")
					if ($main::Debug > 1);
			} #end if #
			
		} elsif  ($resp eq $VOCP::Vars::Data_con_request) {

			VOCP::Util::log_msg("Got $resp which is code for data connect. request. Exiting with $VOCP::Vars::Exit{'DATA'}");
			exit($VOCP::Vars::Exit{'DATA'});

		} else {
			VOCP::Util::log_msg("Retrieved $resp from the queue.")
				if ($main::Debug > 1);
		}#end if dtmf
		
	} #end while not ready
	
	VOCP::Util::log_msg("Input is '$input' after emptying queue")
				if ($main::Debug > 1);
	
	# Return if the queue contained '#'
	if ($done) {
		
		VOCP::Util::log_msg("Returning $input (retrieved from queue)")
			if ($main::Debug);
		
		return $input;
	}
	
	
	#Start waiting for input
	my $pause = $wait || $self->{'pause'} || '10';
	VOCP::Util::log_msg("Waiting $pause sec for user input.")
		if ($main::Debug > 1);
	my $shortpause = int($pause/2);
	
	$self->Write("$Vgetty{'WAIT'} $pause");
	
	while ( !$done) {
	 
	 	# Retrieve the tone
		my $resp = $self->Read($shortpause); # Make sure to set a timeout
		
	 	VOCP::Util::log_msg("Waiting for 'WAIT's READY or '#', got '$resp'")
			if ($main::Debug > 1);
		
		if ($resp eq $Vgetty{'READY'}) {
			
			last;
		
		} elsif ($resp eq $Vgetty{'DTMF'}) { # Got some DTMF
			
			# Retrieve the tone
			next;
			
		} elsif ($resp =~ /[\d\*]+/) { # A digit or * 
				
			$input .= $resp;
				
			VOCP::Util::log_msg("Got input: $resp")
				if ($main::Debug > 1);
				
		} elsif ($resp eq '#') { #user is done
			
			VOCP::Util::log_msg("Got #, user done.")
				if ($main::Debug > 1);
			last;
			
		} elsif ( my $tone = VOCP::Device::VgettyOld::is_tone($resp) ) { #It may be a fax or data conn.
		
			VOCP::Util::log_msg("Expecting DTMF input but got tone ($tone), exiting");
			
			exit ($tone);

		} elsif  ($resp eq $VOCP::Vars::Data_con_request) {

			VOCP::Util::log_msg("Got $resp which is code for data connect. request. Exiting with $VOCP::Vars::Exit{'DATA'}");
			exit($VOCP::Vars::Exit{'DATA'});

		} elsif ($resp eq $Vgetty{'WAITING'} || 
			 $resp eq $Vgetty{'ERROR'} || !$resp) { #waiting, error from wait or empty string
		
			# Just loop 
			next;
			
		} else { # vgetty said something else
		
			VOCP::Util::log_msg("vgetty said: $resp.  Stopping DTMF collection")
				if ($main::Debug);
			
			$done++;
		}
		
	} # END while
  	
	
	$self->stop_and_empty();

	VOCP::Util::log_msg("Got DTMF: $input")
		if ($main::Debug);
	
	return $input;
	
}




=head2 is_tone RESP

Checks whether vgetty\'s RESPonse indicates a FAX or 
DATA tone.  If so, is_tone() returns the value to exit
from the program with, such that vgetty will handle the
incomming connection.

=cut

sub is_tone {
	my $vgetty_resp = shift;
	
	return undef 
		unless ($vgetty_resp);
	
	# Check for the possible tones detected
	return $VOCP::Vars::Exit{'FAX'}
		if ($vgetty_resp eq $Vgetty{'FAX'});
		
	return $VOCP::Vars::Exit{'DATA'}
		if ($vgetty_resp eq $Vgetty{'DATA'});
		
	
	return $VOCP::Vars::Exit{'DATAORFAX'}
		if ($vgetty_resp eq $Vgetty{'DATAORFAX'});
		
	# Not a recognized tone
	return undef;
	
}



=head1 AUTHOR

LICENSE

    VOCP::Device::Vgetty module, part of the VOCP voice messaging system package.
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

Contact page for author available at http://www.psychogenic.com/en/contact.shtml

=head1 SEE ALSO


VOCP, VOCP::Message, VOCP::Util

http://VOCPsystem.com

=cut




1;

__END__
