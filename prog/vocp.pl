#!/usr/bin/perl

use Data::Dumper;
use VOCP;
use VOCP::Vars;
use VOCP::Util;
use strict;

use vars qw {
	$Debug
	$MaxBoxVisits
	$Fake_DTMF
	};

$Debug = 0; #Set > 0 for more verbose logging, >1 for very verbose

### Set MaxBoxVisits to some high but sane maximum number of boxes a user 
### can visit - this is just a fail safe in case the system went into some
### crazy loop or an evil user wanted to keep your system busy forever.
$MaxBoxVisits = 200;


BEGIN {
       # if you don't redirect, it dies after a while when buffer is full
      open STDERR, ">>/var/log/vocp.log"
               || die "can't redirect STDERR";
	       
	my $oldfd = select(STDERR);
	$|=1;
	select ($oldfd);
} 

print STDERR "VOCP Started.\n" if ($Debug);

############ Security environment #############################
$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin';

foreach my $arg (@ARGV)
{
	print STDERR "vocp.pl Got an arg: '$arg'\n" if ($Debug);
}


=head1 vocp

The complete VoiceMail, Pager and phone command shell system.

=head2 DESCRIPTION

This program is the driver for the vocp program.  It uses the VOCP module as an
interface with vgetty, your voice modem and the box system.

=head2 INSTALLATION

Complete installation details are in the README and README.conf files included
with the software.  Basically, set up vgetty to use perl as the shell and vocp.pl
as the call_program.  Also customize the vocp.conf and boxes.conf files.

=head2 DEVELOPERS

Developers may use the Debug global in this program to increase the log verbosity.
Setting Debug to true and setting the global Fake_DTMF will allow you to simulate
user input.

You can also set 'DEVICE' => 'INTERNAL_SPEAKER' in your call to new(), this allows
you to hear messages played on the modem\'s internal speaker.

You should see the pod documentation included in the VOCP module for details.

=head2 AUTHOR

(C) 2000-2003 Pat Deegan, Psychogenic.com

You may reach me through the contact info at http://www.psychogenic.com

LICENSE

    vocp.pl, part of the VOCP voice messaging system.
    Copyright (C) 2000-2003 Patrick Deegan, Psychogenic.com
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


=cut


# main 
{

	
	my $device;
	my $devID = shift @ARGV;
	if ($devID && $devID =~ m|^([\w\d]+)$|)
	{
		$device = $1;
	}
	my $options = {
		'genconfig'	=> $VOCP::Vars::DefaultConfigFiles{'genconfig'},
		'boxconfig'	=> $VOCP::Vars::DefaultConfigFiles{'boxconfig'},
		'voice_device_type'	=> 'vgetty',
		'deviceID'	=> $device,
		};
		
	my $Vocp = VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP object");
	
	print STDERR "VOCP object dump\n" . Dumper($Vocp) if ($Debug > 1);
	#We connect vgetty
	$Vocp->connect()
		|| VOCP::Util::error("Unable to Initialize");

	my $callerIDNumber = $Vocp->{'call'}->{'caller_id'};
	
	my $current = $Vocp->get_start_box() || $VOCP::Default_box;
	my $previousBox = $current;
	
	# We play the message.  During this time the user may
	# press some keys.  This box may also autojump to other boxes
	my $loopcount = 0;
	while ($loopcount++ < $MaxBoxVisits) {
		
		VOCP::Util::log_msg("vocp.pl - Setting current box to '$current'") if ($main::Debug > 1);
		
		
		$Vocp->current_box($current); # set the current box.
		
		# retrieve the object that represents the current box.
		my $currentBoxObject = $Vocp->get_box_object($current)
					|| VOCP::Util::error("Could not fetch the box object for box number '$current'");
		
		# Check that the caller origin is allowed to access this box.
		unless ($currentBoxObject->allowCNDaccess($callerIDNumber))
		{
			VOCP::Util::log_msg("Caller from '$callerIDNumber' attempted to access restricted box $current");
			
			$Vocp->play_error();
			if ($current != $previousBox)
			{
				# bounce back to previous box.
				$current = $previousBox;
				next;
			} else {
				# this is the first box... can't do anything but hang up.
				$Vocp->shutdown(0);
			}
		}
				
		
		
		$Vocp->play_box_message()
			|| VOCP::Util::error("Could not play greeting");
	
		
		# Check if this box is somehow a "terminal box" - end o'the line.
		if (terminate($Vocp, $current))
		{
			# If we get here, we've hit a mail/pager or some other dead end and dealt with it in terminate()
			VOCP::Util::log_msg("vocp.pl - terminating call at box $current")
				if ($Debug);
			$Vocp->shutdown(0);
			
		} 
		
		my $numDigits = $currentBoxObject->numDigits() ;
		VOCP::Util::log_msg("vocp.pl - box expects $numDigits digits from user ") if ($main::Debug && $numDigits);
		
		my $autojump = $Vocp->auto_jump($current); 
		my $waitingInput =  $Vocp->get_dtmf(undef, 0, $numDigits);
		
		
		if ($autojump && $waitingInput =~ m/\d/)
		{
			VOCP::Util::log_msg("vocp.pl - Autojump is set to $autojump and we have '$waitingInput' input in q.") 
					if ($main::Debug);
		
			my $validDestination = $Vocp->valid_box($waitingInput);
			
			$previousBox = $current; # in any case, we will be switching boxes.
			
			if ($validDestination)
			{
				# the waiting input is valid for this box.
				VOCP::Util::log_msg("vocp.pl - It is a valid destination ($validDestination)") if ($main::Debug > 1);
		
				if ($validDestination eq $Vocp->login_num() ) { # login
					do_login($Vocp);
				} else { #set current selection
					
					$current =  $Vocp->current_box($validDestination);
					
				}
				
				
			} else {
			
				# the waiting input is invalid here - perform the autojump and 
				# check whether it might be valid in the next box (performing a type 
				# of kick-through).
				VOCP::Util::log_msg("vocp.pl - Input does not lead to a valid box from here - checking from $autojump") 
						if ($main::Debug > 1);
		
				$current = $Vocp->current_box($autojump);
				$validDestination = $Vocp->valid_box($waitingInput);
				if ($validDestination)
				{
					$current = $Vocp->current_box($validDestination);
				}
				
				
				
			}
			
			# in any case, the current box has changed - so we continue.
			next;
			
		} elsif ($autojump) {
			# autojump is set and no input was entered... 
			# just jump...
			
			VOCP::Util::log_msg("vocp.pl - Box with autojump, no input during play - just jump to $autojump.")
				if ($Debug > 1);
		
			$previousBox = $current; 
			$current = $autojump;
			
			next; # goto autojump and play the autojump box message
		} # end if it has an autojump set, with or without waiting input.
		
		
		
		# Not a dead end and no autojump - get a user selection.
		VOCP::Util::log_msg("vocp.pl - Waiting for user input for box $current.")
			if ($Debug);
		
		
		my $selection = $Vocp->get_selection($waitingInput, undef, $numDigits);
		
		if ($selection eq $Vocp->login_num() ) { # login
			do_login($Vocp);
		} else { #set current selection
			$previousBox = $current;
			$current =  $Vocp->current_box($selection);
		}
		
			
		
	} ;

	# If we get here, we've exceeded the maximum number of box accesses, exit.
	$Vocp->shutdown(0);
	
}
	


sub do_login {
	my $vocp = shift;
	
	VOCP::Util::log_msg("vocp.pl - User attempting to log in.")
				if ($Debug);
	my $continue;
	if ($vocp->login()) { #User logged in

		my $type = $vocp->type();
	
		my $sub;
		if ($type eq 'mail') { #Mail box
			$sub = 'retrieve_messages';
		} elsif ($type eq 'command') { #Command shell
			$sub = 'command_shell';
		} elsif ($vocp->message() && $vocp->password()) { 
			#May want to change msg for a none box
			#So we act as if it were a mailbox
			$sub = 'retreive_messages';
		} else { #You cannot log into this box
		
			$vocp->log_msg("User logged into box which was missing passwd or msg.");
			$vocp->play_goodbye();
			$vocp->shutdown(0);
			
		}
		
		die "do_login: Unknown method $sub"
			unless ($vocp->can($sub));
			
		$continue = $vocp->$sub();
	} else { # Login failed - disconnect call for safety.
	
		$vocp->play_error();
		$vocp->play_goodbye();
		VOCP::Util::log_msg("There was an error loggin in - disconnecting");
		$vocp->shutdown(0);
		
	}
	
	#We've returned from the sub, depending on the return
	#value, we will either return to the root box or exit
	if ($continue) {
		$vocp->current_box($VOCP::Default_box);
		return;
	} else { #All done
		$vocp->play_goodbye();
		$vocp->shutdown(0);
		
	}
	
}

# Checks if this box is the "end of the line" (mail, pager or dead end)
# If so, takes appropriate action and returns true, else
# returns false
sub terminate {
	my $vocp = shift;
	my $current = shift;

	$current ||= $vocp->current_box();

	my $boxType = $vocp->type($current) || 'none';
	if ($boxType eq 'mail') {
	
		my $deliveredMsg = $vocp->record_message() 
			|| VOCP::Util::error("Could not record message for box " .  $current );
		
		sendMailNotification($vocp, $current, $deliveredMsg->[0]);
		
		return 1;
		
	} elsif ($boxType eq 'group') {
	
		my $deliveredMessages = $vocp->record_message()
			|| VOCP::Util::error("Could not record message for box " .  $current );
		
		foreach my $message (@{$deliveredMessages})
		{
			if ($message =~ m|/(\d+)-[^/]+$|)
			{
				my $boxnum = $1;
				sendMailNotification($vocp, $boxnum, $message);
				
			}
		}
		
		return 1;
		
	} elsif ($boxType eq 'pager') {
		
		# Get the number
		# we use get_dtmf because we don't need 
		# validation - any entry is valid
		
		#Beep start entering stuff tone
		$vocp->Beep();
		
		my $number = $vocp->get_dtmf($VOCP::Device::InputMode{'MULTIDIGIT'},10);

		#Beep confirmation, done.
		$vocp->Beep();
		
		$number =~ s/[^\d#\*]+//g; #Clean up whatever we received

		
		my $from = $vocp->getCID();
		my ($text, $subject);
		$text = "$current:$number\n";
		if ($from)
		{
			$subject = "VOCP Pager message from $from";
			$text .= "You received an email pager message from $from in box " 
				."$current. Please call $number\n";
		} else {
			$subject = "VOCP Pager message in box $current";
			
			$text .= "You received an email pager message in box " 
				."$current. Please call $number\n";
		}
	
		$vocp->send_email($current, $text, undef, 'subject' => $subject, 'text' => $text )
			if ($number);

	
		#we're done.
		return 1;
		
	} elsif ($boxType eq 'faxondemand') {
		
		
		$vocp->send_faxondemand($current);
		return 1;

		# This is an idea for faxback (not implemented yet)...
		# $vocp->Beep();
		#my $number = $vocp->get_dtmf();
		#$number =~ s/[^\d#\*]+//g; #Clean up whatever we received
		
		
	} elsif ($boxType eq 'script') {
	
		$vocp->run_script_box($current);
		
		return 1 if ($vocp->dead_end($current));
		
		return 0;
	
	} elsif ($boxType eq 'receivefax') {
		
		# We want to go into fax mode, end of voice communication
		$vocp->receiveFax();
		return 1;
		
		
	} elsif ($boxType eq 'exit' || $vocp->dead_end()) { # This box is the end of the line
	
		#We're ready to exit the system.
		return 1;
	}

	# This is not the end of the line...
	return 0; 
}


sub getLastMessageMetaData {
	my $vocp = shift;
	my $boxnum = shift;
		
	my $box = $vocp->get_box_object($boxnum) || return undef;
	
	my $deliveredMsgNum = $box->getLastMessageNumber();
	
	my $boxMetaData = $box->metaData();
	
	my $messageMetaData = $boxMetaData->messageData($deliveredMsgNum);
	
	return $messageMetaData;
}


sub sendMailNotification {
	my $vocp = shift;
	my $boxnum = shift;
	my $message = shift;
	
	return unless ($vocp->email($boxnum));
	
	#my $messageMetaData = getLastMessageMetaData($vocp, $boxnum) || return;
	#my $from = $messageMetaData->attrib('from');
	
	my $from = $vocp->getCID();
	my $boxname = $vocp->name($boxnum);
	
	my ($subject, $text);
	if ($from && $from ne 'none')
	{
		$from =~ s/[^\s\w\d\.\@_-]+//g;
		$subject = $vocp->{'email_subject'} || 'VOCP Voicemail';
		$subject .= " from $from";
		$text = "You have received a new voice message from $from in ";
		
	} else {
		$text = "You have received a new voice message in ";
	}
	
	$text .= qq|"$boxname", | if ($boxname);
	$text .= "box $boxnum.";

	my $attachbase64 = ($vocp->email_attachements()) ? 1 : 0;
	my $email_content = ($attachbase64) ? $message : $text;
	$vocp->send_email($boxnum, $email_content, $attachbase64,
				'subject'	=> $subject,
				'text'		=> $text);
}

