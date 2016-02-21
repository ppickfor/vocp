
package VOCP::Device::Vgetty;

use base qw (VOCP::Device);
use VOCP::Util;
use VOCP::Vars;
use Modem::Vgetty;
use Data::Dumper;


=head1 NAME

VOCP::Device::Vgetty - talks to the vgetty voice modem driver.

=head1 DESCRIPTION

VOCP::Device::Vgetty uses the Modem::Vgetty module to implement the VOCP::Device interface for
voice modems.

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

Contact page for author available in contact section at 
http://www.psychogenic.com/


=cut

use strict;


use vars qw {
		$DeviceDefined
		$VERSION 
	};
	
$VERSION = $VOCP::Vars::VERSION;

$DeviceDefined = 1;

my %ReadnumGlobals;
my %HandlerGlobals;

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
	'HANGUP'	=> 'LOOP_BREAK',
	'BUSY'		=> 'BUSY_TONE',
	# TIMEOUT is not a vgetty cmd/resp - used
	# for Read() with timeout
	'TIMEOUT'	=> 'TIMEOUT',
	);

sub init {
	my $self = shift;
	my $params = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::connect() called")
		if ($main::Debug);
	
	
	# $Modem::Vgetty::testing = $main::Debug;
	# Temporary hack - Modem::Vgetty has problems when /not/ in testing mode
	# so we force it to 1 (problems involving LOG file handle, patch sent to maintainer)
	$Modem::Vgetty::testing = 1;
	
	$self->{'vgetty'} = new Modem::Vgetty 
			|| VOCP::Util::error("VOCP::Device::Vgetty::connect() Could not create a new Modem::Vgetty object!");
	
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::connect() Got a new Modem::Vgetty device")
		if ($main::Debug > 1);
	
	$self->{'isconnected'} = 1;
	
	my $device = $params->{'device'} || $self->{'device'} || 'DIALUP_LINE';
	if ($device) {
		$self->{'vgetty'}->device($device);
	}
		
	
	####### TEST #########
	$self->{'vgetty'}->autostop('ON');
	
	$HandlerGlobals{$$}{'vgetty'} = $self->{'vgetty'};
	
	$self->{'vgetty'}->add_handler($Vgetty{'DATA'}, 'datatone', sub { exitVoiceShell($VOCP::Vars::Exit{'DATA'}, "Data tone - exit"); });
	$self->{'vgetty'}->add_handler($Vgetty{'FAX'}, 'faxtone', sub { exitVoiceShell($VOCP::Vars::Exit{'FAX'}, "Fax tone - exit"); });
	$self->{'vgetty'}->add_handler($Vgetty{'DATAORFAX'}, 'dataorfaxtone', 
						sub { exitVoiceShell($VOCP::Vars::Exit{'DATAORFAX'}, "Data or fax tone - exit"); });
	
	$self->{'vgetty'}->add_handler($Vgetty{'HANGUP'}, 'hangup', sub { exitVoiceShell(0, "Hangup detected - exit"); });
	
	$ReadnumGlobals{$$}{'readnum_number'} = '';
	my $inputMode = $self->{'inputmode'} || $VOCP::Device::InputMode{'FIXEDDIGIT'};
	$self->inputMode($inputMode);
	
	$ReadnumGlobals{$$}{'vocp_device_obj'} = $self;
	
	
	return 1;
	
}

sub exitVoiceShell {
	my $exitStatus = shift;
	my $message = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::exitVoiceShell($exitStatus) called")
		if ($main::Debug);
	
	sleep (1);
	$HandlerGlobals{$$}{'vgetty'}->stop();
	$HandlerGlobals{$$}{'vgetty'}->waitfor($Vgetty{'READY'});

	
	VOCP::Util::log_msg("VOCP::Device::Vgetty:exitVoiceShell(): $message")
		if ($message);
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::exitVoiceShell Shutting down") if ($main::Debug);
	$HandlerGlobals{$$}{'vgetty'}->shutdown();
	
	exit($exitStatus) if $exitStatus;
	exit(0);
}
	

sub connect {
	my $self = shift;
	my $params = shift;
	
	$self->{'vgetty'}->enable_events();
	return 1;
}


sub disconnect {
	my $self = shift;
	my $params = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::disconnect() called")
		if ($main::Debug);
		
	if ($self->{'isconnected'})
	{
		# The Modem::Vgetty module forcibly calls shutdown on DESTROY
		# If we call it, it generates errors
		$self->{'vgetty'}->shutdown();
		# instead, we shall destroy our instance of the device and 
		#delete $self->{'vgetty'};
		#delete $HandlerGlobals{$$}{'vgetty'};
	}
		
	return 1;
}



=head2 beep FREQUENCY LENGTH

Sends a beep through the chosen device using given frequency (HZ) and length (in miliseconds).  Returns a defined
and true value on success.

=cut

sub beep {
	my $self = shift;
	my $frequency = shift || '';
	my $length = shift || '';
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::beep() called")
		if ($main::Debug);
		
	$self->{'vgetty'}->beep($frequency, $length);
	$self->{'vgetty'}->waitfor($Vgetty{'READY'});
	return 1;
}



=head2 dial DESTINATION

Connects to destination.  Returns defined & true on success.

=cut

sub dial {
	my $self = shift;
	my $destination = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::dial() called")
		if ($main::Debug);
		
	VOCP::Util::error("Must pass a number to dial!", $VOCP::Vars::Exit{'MISSING'})
		unless $destination;
		
	VOCP::Util::error("Invalid phone number passed to VOCP::VgettyOld::dial() '$destination'")
		unless ($destination =~ /^[\dABCD\*#]+$/);

	$self->{'vgetty'}->dial($destination);
	$self->{'vgetty'}->waitfor($Vgetty{'READY'});
	
}


=head2 play PLAYPARAM

plays a sound (file, text-to-speech, whatever is appropriate) base on PLAYPARAM.  May or may not block during
play depending on device implementation.  Returns true on success.

=cut

sub play {
	my $self = shift;
	my $msg = shift;
	my $type = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::play() called for message '$msg'")
		if ($main::Debug);
		
	if ($msg) {
		VOCP::Util::error("VOCP::Device::Vgetty::play really needs absolute paths", $VOCP::Vars::Exit{'MISSING'})
			unless ($msg =~ m|^/|);
	} else {
		VOCP::Util::error("Pass a file to VOCP::Device::Vgetty::play!", $VOCP::Vars::Exit{'MISSING'});
	}
	
	# Make sure we can read the msg
	VOCP::Util::error("$msg either does not exist or is unreadable", $VOCP::Vars::Exit{'FILE'})
		unless (-r $msg);
	
	VOCP::Util::log_msg("Playing message")
		if ($main::Debug);
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::play() sending play to device")
		if ($main::Debug);
	
	$self->blockingPlay($msg, $type);
	
	
	return 1;
}


=head2 record TOFILE

Records input from user to device to file TOFILE.  Returns true on success.

=cut

sub record {
	my $self = shift;
	my $tofile = shift;
	
	my $timeout = $VOCP::Vars::Defaults{'maxMessageTime'} || 45;
	
	if ($timeout !~ /^\d+$/ || $timeout < 2)
	{
		$timeout = 45;
	}
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::record() called")
		if ($main::Debug);
	
	VOCP::Util::error("Must pass a filename to VOCP::Device::Vgetty::record()") 
		unless ($tofile);
	
	# Set up a few signal handlers to stop recording
	
	$self->{'vgetty'}->del_handler($Vgetty{'HANGUP'}, 'hangup');
	$self->{'vgetty'}->add_handler($Vgetty{'HANGUP'}, 'forceStop', sub { _forceStop(); });
	
	$self->{'vgetty'}->add_handler($Vgetty{'SILENCE'}, 'forceStop', sub { _forceStop(); });
	$self->{'vgetty'}->add_handler($Vgetty{'NOVOICE'}, 'forceStop', sub { _forceStop(); });
	$self->{'vgetty'}->add_handler($Vgetty{'BUSY'}, 'forceStop', sub { _forceStop(); });
	
	
	
	eval {
			local $SIG{'ALRM'} = sub { die "alarm\n" }; # NB: \n required
			alarm $timeout;
			$ReadnumGlobals{$$}{'busy'} = 1;
			$self->{'vgetty'}->record($tofile);
			if ($self->{'vgetty'}->expect($Vgetty{'RECORDING'}))
			{
				my $received = $self->{'vgetty'}->expect($Vgetty{'READY'}, $Vgetty{'ERROR'});
				$self->{'vgetty'}->expect($Vgetty{'READY'}) if ($received && $received eq $Vgetty{'ERROR'});
			}
			$ReadnumGlobals{$$}{'busy'} = 0;
			alarm 0;
	};
	
	if ($@) {
		die unless ($@ eq "alarm\n");   # propagate unexpected errors
		# timed out
		VOCP::Util::log_msg("VOCP::Device::Vgetty::record() Timed out during record (lasted longer than $timeout seconds)");
		
		$self->stop();
	}
	
	# Remove our record signal handlers
	$self->{'vgetty'}->del_handler($Vgetty{'HANGUP'}, 'forceStop');
	
	# Not sure we want to exit on phone HUP... need to take care of the recorded file first...
	# $self->{'vgetty'}->add_handler($Vgetty{'HANGUP'}, 'hangup', sub { exitVoiceShell(0, "Hangup detected - exit"); });
	
	
	$self->{'vgetty'}->del_handler($Vgetty{'SILENCE'}, 'forceStop');
	$self->{'vgetty'}->del_handler($Vgetty{'NOVOICE'}, 'forceStop');
	$self->{'vgetty'}->del_handler($Vgetty{'BUSY'}, 'forceStop');
	
	return 1;
}

sub _forceStop {
	$ReadnumGlobals{$$}{'busy'} = 0;
	VOCP::Util::log_msg("VOCP::Device::Vgetty - detected SILENCE/NOVOICE/BUSY/HANGUP sending STOP") if ($main::Debug);
	$HandlerGlobals{$$}{'vgetty'}->stop();
}

sub _imstop {

	
	$ReadnumGlobals{$$}{'busy'} = 0;
	#$HandlerGlobals{$$}{'vgetty'}->stop();
	#$HandlerGlobals{$$}{'vgetty'}->waitfor($Vgetty{'READY'});
}

=head2 wait TIME

Simply waits for TIME seconds.  Device should accept/queue user input 
during interval.

=cut

sub wait {
	my $self = shift;
	my $time = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::wait($time) called")
		if ($main::Debug);
	
	$ReadnumGlobals{$$}{'busy'} = 1;
	$self->{'vgetty'}->wait($time);
	$self->{'vgetty'}->waitfor($Vgetty{'READY'});
	$ReadnumGlobals{$$}{'busy'} = 0;
	return 1;
}


=head2 waitFor STATE

Waits until STATE is reached/returned by device.  Device should accept/queue user input 
during interval.

=cut

sub waitFor {
	my $self = shift;
	my $state = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::waitFor($state) called")
		if ($main::Debug);
	
	$self->{'vgetty'}->waitfor($state);

}


=head2 stop

Immediately stop any current activity (wait, play, record, etc.).

=cut
sub stop {
	my $self = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::stop() called")
		if ($main::Debug);
		
	$ReadnumGlobals{$$}{'busy'} = 0;
	$self->{'vgetty'}->stop();
	$self->{'vgetty'}->waitfor($Vgetty{'READY'});

}

=head2 blocking_play PLAYTHIS

play PLAYTHIS and return only when done.

=cut

sub blockingPlay {
	my $self = shift;
	my $playthis = shift;
	my $type = shift || '';
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::blockingPlay() called ('$playthis' $type)")
		if ($main::Debug);
	
	VOCP::Util::error("Must pass a file to play to VOCP::Device::Vgetty::blockingPlay()")
		unless ($playthis);
		
	
	VOCP::Util::error("VOCP::Device::Vgetty::blockingPlay(): Can't find file '$playthis'")
		unless (-e $playthis);
		
	VOCP::Util::error("VOCP::Device::Vgetty::blockingPlay(): Can't read file '$playthis'")
		unless (-r $playthis);
	
	#$self->stop(); #Just in case we're already doing something...
	$ReadnumGlobals{$$}{'busy'} = 1;
	$self->{'vgetty'}->play_and_wait($playthis);
	$ReadnumGlobals{$$}{'busy'} = 0;
	
	return 1;
}



=head2 inputMode [MODE]

Returns the current input mode (single- or multi- digit currently supported), optionally setting to 
MODE, if passed - use the %VOCP::Device::InputMode hash for valid MODE values.

=cut

sub inputMode {
	my $self = shift;
	my $setTo = shift;
	my $numDigits = shift; #optionally set number of digits to expect
	
	if (defined $setTo)
	{
		$self->{'inputmode'} = $setTo;
		$self->{'vgetty'}->del_handler('RECEIVED_DTMF', 'readnum');
		if ($setTo == $VOCP::Device::InputMode{'FIXEDDIGIT'})
		{
			VOCP::Util::log_msg("VOCP::Device::Vgetty::inputMode() Setting to fixed digit")
				if ($main::Debug);
				
			$self->{'vgetty'}->add_handler('RECEIVED_DTMF', 'readnum', \&readnum_event_fixed);
			$ReadnumGlobals{$$}{'readnum_mode'} = $VOCP::Device::InputMode{'FIXEDDIGIT'};
			$ReadnumGlobals{$$}{'numDigits'} = $numDigits;
			
		} elsif ($setTo == $VOCP::Device::InputMode{'MULTIDIGIT'})
		{
			VOCP::Util::log_msg("VOCP::Device::Vgetty::inputMode() Setting to multi digit")
				if ($main::Debug);
				
			
			$self->{'vgetty'}->add_handler('RECEIVED_DTMF', 'readnum', \&readnum_event_multi);
			$ReadnumGlobals{$$}{'readnum_mode'} = $VOCP::Device::InputMode{'MULTIDIGIT'};
		} else {
			VOCP::Util::error("VOCP::Device::Vgetty::inputMode() Unrecognized mode '$setTo' passed");
		}
			
	}
	
	return $self->{'inputmode'};
}


=head2 readnum PLAYTHIS TIMEOUT [REPEATTIMES [NUMDIGITS [INCLUDEPOUND]]]

Plays the PLAYTHIS and then waits for the sequence of the digit input finished. If no are entered within TIMEOUT 
seconds, it re-plays the message again. It returns failure (undefined value) if no digits are entered after the message
has been played REPEATTIMES (defaults to 3) times. 


It returns a string (a sequence of DTMF tones 0-9,A-D and `*') without the final stop key (normally '#'). 


=cut


sub readnum {
	my $self = shift;
	my $playthis = shift;
	my $timeout = shift; 
	my $repeatTimes = shift || 1;
	my $numDigits = shift || '';
	my $includePound = shift;
	
	
	
	$timeout = $self->{'timeout'} || 6 unless (defined $timeout);
	my $playfileName = $playthis || ''; # annoying warnings for log_msg if we don't do this
	VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum($playfileName, $timeout, $repeatTimes, $numDigits) called")
		if ($main::Debug);
	
	my $readnumid = $$; # So it's safe to have multiple devices...
	
	if ($numDigits)
	{
		$ReadnumGlobals{$readnumid}{'numDigits'} = $numDigits;
	} elsif (! $ReadnumGlobals{$readnumid}{'numDigits'} )
	{
		$ReadnumGlobals{$readnumid}{'numDigits'} = 1;
	}
	
	my $retnum = defined $ReadnumGlobals{$readnumid}{'readnum_number'} ? 
				$ReadnumGlobals{$readnumid}{'readnum_number'} : '';
	
	# Special case when timeout is set to 0 - return stored number immediately.
	# Also, if we're in FIXEDDIGIT mode and we have enough digits, return those immediately
	# don't wait for any further input.
	if ($timeout == 0 
		|| ($ReadnumGlobals{$$}{'readnum_mode'} == $VOCP::Device::InputMode{'FIXEDDIGIT'} 
			&& length($retnum) >= $ReadnumGlobals{$readnumid}{'numDigits'}) )
	{
		delete $ReadnumGlobals{$readnumid}{'readnum_number'};
		return $retnum;
	}
	
	$ReadnumGlobals{$readnumid}{'include_pound'} = $includePound;
	
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() retnum currently '$retnum'")
			if ($main::Debug > 1);
	
	# Modem::Vgetty's readnum *requires* a sound file so we need 
	# a bit of cut&paste coding - I'm submitting a patch to the author but
	# in the mean time...
	
	if ($ReadnumGlobals{$readnumid}{'stop'} && $retnum =~ /[\d\*]+/)
	{
		VOCP::Util::log_msg('VOCP::Device::Vgetty::readnum() Already have stop flag set - '
					. "assuming read done in previous play/wait and returning '$retnum'")
			if ($main::Debug);
		
		if ($numDigits && length($retnum) >= $numDigits)
		{
			# Reset our flags
			$ReadnumGlobals{$readnumid}{'stop'} = 0;
			$ReadnumGlobals{$readnumid}{'readnum_called'} = 0;
			$ReadnumGlobals{$readnumid}{'readnum_number'} = '';
			return $retnum;
		}
	}
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() Entering read loop...")
		if ($main::Debug > 1);
	
	my $times = $repeatTimes;
	
	$ReadnumGlobals{$readnumid}{'stop'} = 0;
	$ReadnumGlobals{$readnumid}{'readnum_called'} = 1;
	$ReadnumGlobals{$readnumid}{'readnum_number'} = '';
 	$ReadnumGlobals{$readnumid}{'readnum_timeout'} = $timeout if $timeout != 0;
	
	while( (! $ReadnumGlobals{$readnumid}{'stop'}) && ($times-- > 0) ) {
		
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() Outer loop...")
				if ($main::Debug > 1);
		
		
		
		if ($ReadnumGlobals{$readnumid}{'stop'})
		{
			VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() stop flag is set, exit loop.")
				if ($main::Debug);
			$ReadnumGlobals{$readnumid}{'stop'} = 0;
			last ;
		}
		
		$ReadnumGlobals{$readnumid}{'readnum_in_timeout'} = 1;
		
		$self->blockingPlay($playthis) if ($playthis);
		
		while ($ReadnumGlobals{$readnumid}{'readnum_in_timeout'} != 0) {
		
			VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() Inner loop, waiting on input/timeout.")
				if ($main::Debug > 1);
				
				
			$ReadnumGlobals{$readnumid}{'readnum_in_timeout'} = 0;
			$self->wait($ReadnumGlobals{$readnumid}{'readnum_timeout'});
			
			
        	}
		
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() Inner loop '#' input or timeout (" 
					. $ReadnumGlobals{$readnumid}{'readnum_number'} . ')')
				if ($main::Debug > 1);
		
		
    	} # end while not 'stop'ed and repeat times not done
	
	# Add everything we got in the readnum_number global to our return number
	$retnum .= $ReadnumGlobals{$readnumid}{'readnum_number'};

	# Reset out globals to empty
	$ReadnumGlobals{$readnumid}{'readnum_called'} = 0;
	$ReadnumGlobals{$readnumid}{'readnum_number'} = '';

	if ($times < 0)
	{
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() input or timeout timedout - returning '$retnum'.")
			if ($main::Debug);
		return $retnum ;
	}
	
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum() Done. Returning '$retnum'")
				if ($main::Debug);
	# clear num digits to expect
	delete $ReadnumGlobals{$readnumid}{'numDigits'};
	return $retnum;
}

#### Reads any number of digits, up to #
sub readnum_event_multi {
	my $vgetty = shift;
	my $input = shift;
	my $dtmf = shift;
	
	$dtmf = '' unless (defined $dtmf);
	
	my $readnumid = $$;
	
	if ( ($main::Debug > 1) && $ReadnumGlobals{$readnumid}{'readnum_number'} eq '')
	{
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_multi()  - First digit press.");
	}
	
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_multi()  - Got a '$dtmf'")
		if ($main::Debug);
	
	
	
	if ($dtmf eq '#') { # Stop the reading now.
	
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_multi()  - Got a '#' setting all stop flags.")
			if ($main::Debug);
		$ReadnumGlobals{$readnumid}{'readnum_in_timeout'} = 0;
		$ReadnumGlobals{$readnumid}{'stop'}  = 1;
		
		$ReadnumGlobals{$readnumid}{'readnum_number'} .='#' if ($ReadnumGlobals{$readnumid}{'include_pound'});
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_multi()  - sending STOP to vgetty.")
			if ($main::Debug);
		
		if ($ReadnumGlobals{$$}{'busy'})
		{
			VOCP::Util::log_msg("readnum_event_multi() sending STOP.") if ($main::Debug);
			_imstop();
			#$vgetty->stop();
			#$vgetty->waitfor($Vgetty{'READY'});
		}
		
 		return;
	} elsif ($dtmf eq '*')
	{
		if ($ReadnumGlobals{$readnumid}{'readnum_number'} =~ /[\dA-D]+/i)
		{
			# Not first key, add the *
			$ReadnumGlobals{$readnumid}{'readnum_number'} .= $dtmf;
		} 
	} else {
	
		$ReadnumGlobals{$readnumid}{'readnum_number'} .= $dtmf;
	}
	
	# Reset the wait flag
	$ReadnumGlobals{$readnumid}{'readnum_in_timeout'} = 1;
	
	return;
}



sub readnum_event_fixed {
	my $vgetty = shift;
	my $input = shift;
	my $dtmf = shift;
	
	$dtmf = '' unless (defined $dtmf);
	
	my $readnumid = $$;
	VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_fixed()  - Got a '$dtmf'")
		if ($main::Debug);
	
	
	$ReadnumGlobals{$readnumid}{'readnum_number'} = '' unless (defined $ReadnumGlobals{$readnumid}{'readnum_number'});
	my $numDigits = $ReadnumGlobals{$readnumid}{'numDigits'} || 1;
	
	if ( ($main::Debug > 1) && $ReadnumGlobals{$readnumid}{'readnum_number'} eq '')
	{
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_fixed()  - First digit press.");
	}
	
	if ($dtmf eq '#') { # Stop the reading now.
	
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_fixed()  - Got a '#' setting all stop flags.")
			if ($main::Debug);
		$ReadnumGlobals{$readnumid}{'readnum_in_timeout'} = 0;
		$ReadnumGlobals{$readnumid}{'stop'}  = 1;
		$ReadnumGlobals{$readnumid}{'readnum_number'} .='#' if ($ReadnumGlobals{$readnumid}{'include_pound'});
		delete $ReadnumGlobals{$readnumid}{'readnum_mode'} ;
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_fixed()  - sending STOP to vgetty.")
			if ($main::Debug);
		if ($ReadnumGlobals{$$}{'busy'})
		{
			_imstop();
			#$vgetty->stop() ;
			#$vgetty->waitfor($Vgetty{'READY'});
			#$ReadnumGlobals{$$}{'busy'} = 0;
		}
		
	} elsif ($dtmf eq '*' && (length($ReadnumGlobals{$readnumid}{'readnum_number'}) < 1) )
	{
	
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_fixed() - got a '*' while in single mode, switching to multi")
			if ($main::Debug);
		
		# this is the first key press, switch to multidigit mode
		$ReadnumGlobals{$readnumid}{'vocp_device_obj'}->inputMode($VOCP::Device::InputMode{'MULTIDIGIT'});
		#$ReadnumGlobals{$readnumid}{'readnum_mode'} = $VOCP::Device::InputMode{'MULTIDIGIT'};
		
		$vgetty->del_handler('RECEIVED_DTMF', 'readnum');
		$vgetty->add_handler('RECEIVED_DTMF', 'readnum', \&readnum_event_multi);
		if ($ReadnumGlobals{$$}{'busy'})
		{	
			$vgetty->waitfor($Vgetty{'READY'});
			$ReadnumGlobals{$$}{'busy'} = 0;
		
		}
		$vgetty->wait('6');
		

	} else {
		# We have a digit, we are not in multi digit mode.
		# So we assign the digit and set the stop flag
		
		VOCP::Util::log_msg("VOCP::Device::Vgetty::readnum_event_fixed() - got a digit ($dtmf)")
			if ($main::Debug);
		
		$ReadnumGlobals{$readnumid}{'readnum_number'} .= $dtmf;
		
		if (length($ReadnumGlobals{$readnumid}{'readnum_number'}) >= $numDigits)
		{
		
			$ReadnumGlobals{$readnumid}{'readnum_in_timeout'} = 0;
			$ReadnumGlobals{$readnumid}{'stop'}  = 1;
		
			if ($ReadnumGlobals{$$}{'busy'})
			{
				VOCP::Util::log_msg("readnum_event_fixed() Got enough digits, sending STOP.") if ($main::Debug);
			
				_imstop();
				#$vgetty->stop() ;
				#$vgetty->waitfor($Vgetty{'READY'});
				#$ReadnumGlobals{$$}{'busy'} = 0;
		
			}
		} else {
			
			$ReadnumGlobals{$readnumid}{'readnum_in_timeout'} = 1; # continue accepting input.
		}
	}
	
	return;
}



=head2 validDataFormats 

Returns an array ref of valid data formats (eg 'rmd', 'wav', 'au') the device will accept.

=cut

sub validDataFormats {
	my $self = shift;
	
	VOCP::Util::log_msg("VOCP::Device::Vgetty::validDataFormats() called")
		if ($main::Debug);
	
	my @validFormats = ('rmd');
	
	return \@validFormats;
}


sub receiveImage {
	my $self = shift;
	exitVoiceShell($VOCP::Vars::Exit{'FAX'}, "Device::Vgetty receiveImage called");
}

sub sendImage {
	my $self = shift;
	my $file = shift;
	
	$self->{'vgetty'}->send("$Vgetty{'SENDFAX'} $file");
	
	my $resp = $self->{'vgetty'}->receive();
	
	VOCP::Util::log_msg("VOCP SENDFAX said: '$resp'")
		if ($main::Debug || $resp ne 'HUP_CODE');
		
	return 1;
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
