#!/usr/bin/perl -w

use VOCP;
use VOCP::Vars;
use VOCP::Util;

$|++;

use strict;

use vars qw {
	$Debug
	$CALLER_ID
	$CALLER_NAME
	$Fake_DTMF
	$MaxBoxVisits
	$UsePwCheck
	};

$Debug = 1; #Set > 0 for more verbose logging, >1 for very verbose


$CALLER_ID = '514-555-1212';
$CALLER_NAME = 'VOCPLocal';

# Set the $UsePwCheck to 1 to allow any system
# user to play with vocplocal
$UsePwCheck = 0;

$MaxBoxVisits = 400;
#$Fake_DTMF = '888'; # Define this to fake some DTMF input


############ Security environment #############################

foreach my $key (keys %ENV)
{
	delete $ENV{$key} unless ($key =~ m|^VOICE|i);
}

$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin';


=head1 vocp

The complete VoiceMail, Pager and phone command shell system.

=head2 DESCRIPTION

This program is the is a modified version of the vocp.pl driver.
It uses the VOCP module and the VOCP::Device::Local to use your speakers
(through /dev/dsp) so the system admin can test the current configuration.

You will either need to start the program as root or do a 

 # chown root:vocp /usr/local/vocp/bin/vocplocal.pl
 # chmod 2755 /usr/local/vocp/bin/vocplocal.pl

Please note that this configuration will allow anyone to play with this 
program.


=head2 AUTHOR

(C) 2002 Pat Deegan, Psychogenic.com
All rights reserved.

You may reach me through the contact info at http://www.psychogenic.com

LICENSE

    vocplocal.pl, part of the VOCP voice messaging system.
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

	# Set up VOCP to use the local driver
	$ENV{'CALLER_ID'} = $CALLER_ID;
	$ENV{'CALLER_NAME'} = $CALLER_NAME;
	my $options = {

		'usepwcheck'	=> $UsePwCheck, 

		'genconfig'	=> $VOCP::Vars::DefaultConfigFiles{'genconfig'},
		'boxconfig'	=> $VOCP::Vars::DefaultConfigFiles{'boxconfig'},
		'voice_device_type'	=> 'local',
		'voice_device_params'	=> {
						'readnumcallback' => \&readnum,
						'device'	=> '/dev/dsp',
						'buffer'	=> 4096,
						'channels'	=> 1,
						'rate'		=> 8000,
					},

		#'nocalllog'	=> 1, # no need for logging here...
		
		};
	my $Vocp = VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP object");
	
	#print STDERR Dumper($Vocp);
	#We connect vgetty
	$Vocp->connect()
		|| VOCP::Util::error("Unable to Initialize");
		
	my $current = $Vocp->get_start_box() || $VOCP::Default_box;
	
	
	# We play the message.  During this time the user may
	# press some keys.  This box may also autojump to other boxes
	my $loopcount = 0;
	do {
		$Vocp->current_box($current);
		
		$Vocp->play_box_message()
			|| VOCP::Util::error("Could not play greeting");
	
		my $autojump = $Vocp->auto_jump($current); 
		if (terminate($Vocp, $current))
		{
			# If we get here, we've hit a mail/pager or some other dead end and dealt with it in terminate()
			VOCP::Util::log_msg("vocp.pl - terminating call at box $current")
				if ($Debug);
				
			exit(0);
		} elsif ($autojump)
		{
			# Not a dead end, has autojump set - check for user input and deal with it or perform the 'jump'
			VOCP::Util::log_msg("vocp.pl - Box $current not a terminal box, has autojump set.")
				if ($Debug);
				
			my $waitingInput = $Vocp->get_dtmf(undef, 0);
			if ($waitingInput =~ /\d+/)
			{
			
				if ($Vocp->valid_box($waitingInput))
				{
					VOCP::Util::log_msg("vocp.pl - Selection $waitingInput leads to a valid box.")
						if ($Debug );
					# Requested a selection during play, we oblige the user
					my $selection = $Vocp->get_selection($waitingInput);
				
					VOCP::Util::log_msg("vocp.pl - User entered valid input ($waitingInput) before autojump occured. "
							. "Setting current to $selection")
						if ($Debug);
				
					if ($selection eq $Vocp->login_num() ) { # login
						do_login($Vocp);
					} else { #set current selection
						$current =  $Vocp->current_box($selection);
					}
				} else {
					VOCP::Util::log_msg("vocp.pl - Selection $waitingInput does not lead to a valid box "
								. "for box $current, checking $autojump.")
						if ($Debug );
						
					$Vocp->current_box($autojump);
					
					if ($Vocp->valid_box($waitingInput))
					{
						VOCP::Util::log_msg("vocp.pl - Selection $waitingInput leads to a valid box in $autojump")
							if ($Debug);
						my $selection = $Vocp->get_selection($waitingInput);
						
						VOCP::Util::log_msg("vocp.pl - User entered valid input ($waitingInput) after "
								. "autojump occured. Setting current to $selection")
							if ($Debug);
				
						if ($selection eq $Vocp->login_num() ) { # login
							do_login($Vocp);
						} else { #set current selection
							$current =  $Vocp->current_box($selection);
						}
					} else {
						VOCP::Util::log_msg("vocp.pl - Selection $waitingInput does not lead to a valid "
									. "box from $autojump.  Simply jumping to $autojump")
							if ($Debug);
					} # end if waitinginput leads to a valid_box from autojump destination
					
				} # end if waitinginput leads to a valid_box from current
			} else {
				$current = $autojump;
				VOCP::Util::log_msg("vocp.pl - Setting current to $current.")
					if ($Debug);
			}
			
		} else {
		
			# Not a dead end and no autojump - get a user selection.
			VOCP::Util::log_msg("vocp.pl - Waiting for user input for box $current.")
				if ($Debug);
				
			my $selection = $Vocp->get_selection();
			if ($selection eq $Vocp->login_num() ) { # login
				do_login($Vocp);
			} else { #set current selection
				$current =  $Vocp->current_box($selection);
			}
		}
		
	} while ($loopcount++ < $MaxBoxVisits);


	exit(0);
	
}
	
	

sub do_login {
	my $Vocp = shift;
	
	my $continue;
	if ($Vocp->login()) { #User logged in

		my $type = $Vocp->type();
	
		my $sub;
		if ($type eq 'mail') { #Mail box
			$sub = 'retrieve_messages';
		} elsif ($type eq 'command') { #Command shell
			$sub = 'command_shell';
		} elsif ($Vocp->message() && $Vocp->password()) { 
			#May want to change msg for a none box
			#So we act as if it were a mailbox
			$sub = 'retreive_messages';
		} else { #You cannot log into this box
		
			$Vocp->log_msg("User logged into box which was missing passwd or msg.");
			$Vocp->play_goodbye();
			$Vocp->disconnect();
			exit(0);
		}
		
		die "do_login: Unknown method $sub"
			unless ($Vocp->can($sub));
			
		$continue = $Vocp->$sub();
	} else { # Login failed - disconnect call for safety.
	
		$Vocp->play_error();
		$Vocp->play_goodbye();
		$Vocp->disconnect();
		VOCP::Util::log_msg("There was an error loggin in - disconnected");
		exit(0);
	}
	
	#We've returned from the sub, depending on the return
	#value, we will either return to the root box or exit
	if ($continue) {
		$Vocp->current_box($VOCP::Default_box);
		return;
	} else { #All done
		$Vocp->play_goodbye();
		$Vocp->disconnect();
		exit(0);
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
		
		#$Fake_DTMF = '5551212';
	
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
	
		$vocp->send_email($current, $text, undef, 'subject' => $subject )
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


sub readnum {
	
	print STDOUT "\nEnter DTMF Selection ([0-9]+<ENTER>):";
	my $num = <STDIN>;
	chomp($num);
	$num =~ s/[^\d\*]+//g;
	
	return $num;
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
	
	my ($subject, $text);
	if ($from && $from ne 'none')
	{
		$from =~ s/[^\s\w\d\.\@_-]+//g;
		$subject = $vocp->{'email_subject'} || 'VOCP Voicemail';
		$subject .= " from $from";
		
		$text = "You have received a new voice message from $from (box $boxnum).";
	} else {
		$text = "You have received a new voice message (box $boxnum).";
	}
	
	my $attachbase64 = ($vocp->email_attachements()) ? 1 : 0;
	my $email_content = ($attachbase64) ? $message : $text;
	
	
	VOCP::Util::log_msg("Would have sent email to '" . $vocp->email($boxnum) . "' With subject '$subject' and text :\n$text");
	#$vocp->send_email($boxnum, $email_content, $attachbase64,
	#			'subject'	=> $subject,
	#			'text'		=> $text);
}
