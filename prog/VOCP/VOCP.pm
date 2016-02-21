package VOCP;

require 5.005_62;
use strict;

require Exporter;
use AutoLoader qw(AUTOLOAD);

use vars qw {
		@ISA
		%EXPORT_TAGS
		@EXPORT_OK
		$VERSION
		@EXPORT
	};
	

@ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use VOCP ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
%EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

@EXPORT = qw(
	
);
$VERSION = '0.9.3';

use FileHandle;
use Data::Dumper;

#use lib '.';
use VOCP::Vars;
use VOCP::Util;
use VOCP::Box;
use VOCP::Message;
use VOCP::Util::DeliveryAgent;
use VOCP::Util::CallMonitor;
use VOCP::Config::Simple;
use VOCP::Config::Box;
use VOCP::Device::Factory;
use VOCP::PipeHandle;

use strict;

use vars qw{
	$Default_box
	$Die_on_error
	};

my $License = join( "\n",  
qq|###################     VOCP.pm     #####################|,
qq|######                                            #######|,
qq|######    Copyright (C) 2000-2003  Pat Deegan     #######|,
qq|######             All rights reserved            #######|,
qq|#                                                       #|,
qq|#             http://www.VOCPsystem.com                 #|,
qq|#                                                       #|,
qq|#   This program is free software; you can redistribute #|,
qq|#   it and/or modify it under the terms of the GNU      #|,
qq|#   General Public License as published by the Free     #|,
qq|#   Software Foundation; either version 2 of the        #|,
qq|#   License, or (at your option) any later version.     #|,
qq|#                                                       #|,
qq|#   This program is distributed in the hope that it will#|,
qq|#   be useful, but WITHOUT ANY WARRANTY; without even   #|,
qq|#   the implied warranty of MERCHANTABILITY or FITNESS  #|,
qq|#   FOR A PARTICULAR PURPOSE.  See the GNU General      #|,
qq|#   Public License for more details.                    #|,
qq|#                                                       #|,
qq|#   You should have received a copy of the GNU General  #|,
qq|#   Public License along with this program; if not,     #|,
qq|#   write to the Free Software Foundation, Inc., 675    #|,
qq|#   Mass Ave, Cambridge, MA 02139, USA.                 #|,
qq|#                                                       #|,
qq|#   You may contact the author, Pat Deegan, by email    #|,
qq|#   at prog\@vocpsystem.com.  My home page              #|,
qq|#   may be found at http://www.psychogenic.com          #|,
qq|#                                                       #|,
qq|#########################################################|,
);



# The default (root) box number.
$Default_box = $VOCP::Vars::Defaults{'rootboxnum'};


# vgetty keywords,
# commands and responses - this avoids needing to modify
# lots of code if vgetty changes something to the 'API'

# Prepare the Error hash
# This hash may be used to map exit codes to error type.
# It is the inverse of the %Exit hash (i.e. 249 => 'FILE' etc).
my %Error;
while ( my ($key, $val) = each %VOCP::Vars::Exit) {
	$Error{$val} = $key;
}
	


# Stores the relation between weekday returned by localtime
# and the weekday itself.
# Used by messages_date() to say day of message creation.	
my %Days = (
	'0'	=> 'sunday',
	'1'	=> 'monday',
	'2'	=> 'tuesday',
	'3'	=> 'wednesday',
	'4'	=> 'thursday',
	'5'	=> 'friday',
	'6'	=> 'saturday',
);

$Die_on_error = $VOCP::Util::Die_on_error;

my $VocpLocalDir = $VOCP::Vars::VocpLocalDir;

# A few test/debugging related vars:
my $DEADBEEF = $VOCP::Util::DEADBEEF;
my $TestBoxNum = $VOCP::Util::TestBoxNum;


=head1 NAME

	VOCP - Interface to vgetty/voice modems and box system.

=head1 SYNOPSIS

	# Create a new VOCP object and set the location of the config file	
	my $Vocp = VOCP->new('genconfig'	=> '/etc/vocp/vocp.conf')
		|| VOCP::Util::error("Unable to create new VOCP");
		
	#We connect vgetty and the voice modem
	$Vocp->connect()
		|| VOCP::Util::error("Unable to Initialize");
	
	#Set the current box (the root of the system)
	$Vocp->current_box('000');
	
	# We play the message.  During this time the user may
	# press some keys - which are returned by the function
	 my $input = $Vocp->play_box_message()
		|| VOCP::Util::error("Could not play greeting");
	
	# We get the user's selection, passing any input we
	# may have recieved while playing
	my $selection = $Vocp->get_selection($input);


	# Set the current box according to input
	$Vocp->current_box($selection);
	
	# Play the selected boxe's message
	$input = $Vocp->play_box_message();
		
	if ($Vocp->is_mailbox()) {
		
		$Vocp->record_message() 
			|| VOCP::Util::error("Could not record message for box "
					. $Vocp->current_box() );
	}


=head1 ABSTRACT

  This perl library uses a VOCP object to represent the entire 
telephone (DTMF) operated vocal system.
The system consists of a number of voicemail boxes, email pagers 
and command shells.  User's call
the system and navigate the menus using the dtmf keys on their 
phone.

=head2 COMPONENTS

Voicemail boxes consist of boxes where users may leave vocal 
messages.  Voicemail boxes may 
be configured to email the owners when a new message 
is left in the box.

Pager boxes consist of boxes where users may enter a dtmf 
sequence to be emailed to the box owner.

Command shells consist of (password protected) boxes within which 
the user may execute a set of programs on the host machine using 
DTMF sequences.  The return value of the program or 
it's (numerical) output is read to the user after the command has run.

The boxes may have restricted access set, such that a password is
requested and validated before the user hears the associated 
message and may proceed to leave a message.

The voicemail boxes may be accessed by the owner (using a password)
to retrieve or delete voicemail messages.


=head2 CONFIGURATION

  Please see the documentation included with this module and 
within the configuration files (vocp.conf, general program 
config, and boxes.conf, the box and command shell config).

=head2 NAVIGATION

Navigation throughout the system is done with DTMF input.  
Pressing the pound (#) sign tells the system to stop waiting
for further input.A user may enter a box number to access
the box directly.

  Boxes may be setup to branch to other boxes (e.g. in box 001
the user has a choice between pressing '1' for english and '2'
to french - which lead him into box 010 or 020 according to his
selection), creating a tree of messages and boxes that the user 
may access.

  Navigation through the system ceases when the user ends up in
either a voicemail box, a pager box or a dead end.  In cases 
where you don't the user to leave a message (it is a dead end) 
but do not wish to have the connection terminated (say a box 
which tells users your location and hours) you may configure 
the box to 'auto jump' to another box, for example the main menu. 


There is one special number that is reserved for entering the
message retrieval mode and the various command shell boxes.  By 
default, the number is '999' - it may be set to different values 
in the config file or during the call to new().
When the user enters one of these numbers, the number of the 
voicemail or command shell box to access is requested followed 
by a request for the associated password.  If these are correct, 
the user may access his messages or enter commands for the 
command shell.

Message retrieval.

When in message retrieval mode, the user may select the following 
options: play, delete, date, help or quit.  Each action has an
associated number, by default:

	1	play
	3	delete
	5	date
	9	help
	0	quit

The keys following the action number indicate which message 
to apply the action to.  For example, '115' will play ('1')
message 15, and 309 will delete ('3') message 09.  The special
sequence '00' after an action code indicates that the command
should be applied to ALL messages, thus '300' deletes all the
user's messages.

The date ('5') option reads the user the day and time at which
a message was created.


Command shell.


Command shell boxes allow users to execute arbitrary programs
(must be setup by the system admin) by entering DTMF sequences.
Depending on the command configuration, the return code or the
(numerical) ouput of the program will be read to the user.

For security reasons, all command shells must be password 
protected.  The programs are executed with the priviledges
associated with the box owner (the programs run suid to the 
box owner).  
Also, the program sets for the command shells must all be 
contained under the commanddir directory (set in the configuration
file or with new()).  You may use symlinks in the commanddir
directory to the programs you wish to be able to execute in the 
shells.


You may have any number of different command shells, each with 
it\'s own password, owner and set of executable programs.


=head1 DESCRIPTION

The normal sequence of events for the voicemail system is:

	1 Object creation
	2 Connection to vgetty
	3 User input
	4 Play message
	5 Record messages/page if box else go to step 3
	
Special cases are when the user inputs the code for message 
retrieval or command shells, in which case the user lands in 
the appropriate environment and issues commands until he 
chooses to quit.


=head2 OBJECT METHODS


########  Creating and initializing a new object  ########

=head2 new OPTIONS

Blesses a new VOCP object, calls init and returns a ref to the object.
OPTIONS in an href of settable binary (i.e. A = B) options.

The most important option to set in OPTIONS is genconfig, the full path
to the general VOCP configuration file.

Note:  If die_on_error is set to true during the call to new() or 
VOCP::Die_on_error is set true, then error() will die instead of exiting
with an exit code.
This is usefull, for example, when wrapping calls to new() in an eval, 
to trap the errors.

=cut

sub new {
	my $class = shift;
	my $options = shift;
	
	my $self = {};
	
	bless $self, ref $class || $class;
    
	$self->init($options) || return undef;
	
	$self;
}


=head2 init OPTIONS

Initializes the new VOCP object with default values, overrides
defaults with the corresponding values in the OPTIONS href if
they are set.  Calls read_config() to read in the genconfig
file

=cut

# Initialise the object
sub init {
	my $self = shift;
	my $options = shift;

	VOCP::Util::log_msg("Initializing a new VOCP object. ")
		if ($main::Debug > 1);

	my %defaults = (
		'device'	=> 'DIALUP_LINE',
		'pvftooldir'	=> $VOCP::Vars::Defaults{'pvftooldir'},
		'voice_device_type'	=> $VOCP::Vars::Defaults{'voice_device_type'},
		'genconfig'	=> $VOCP::Vars::Defaults{'genconfig'},
		'boxconfig'	=> $VOCP::Vars::Defaults{'boxconfig'},
		'inboxdir'	=> $VOCP::Vars::Defaults{'inboxdir'},
		'messagedir'	=> $VOCP::Vars::Defaults{'messagedir'},
		'commanddir'	=> $VOCP::Vars::Defaults{'commanddir'},
		'tempdir'	=> $VOCP::Vars::Defaults{'tempdir'} || '/tmp',
		'usepwcheck'	=> 0, # True = use the pwcheck exec to check for valid passwords (usefull for reduced privs)
		'call_logfile'	=> $VOCP::Vars::Defaults{'calllog'}, # which file to log incomming calls/messages to
		'nocalllog'	=> 0, # True = do NOT open a calllog logfile
		
	);
	
	#Set up defaults
	while ( my ($key, $val) = each %defaults) {
		$self->{$key} = $val;
	}
	
	
	#Set up options passed to new (override defaults, but NOT genconfig(for the moment, because of fd problems w/vgetty))
	foreach my $key ( keys %{$options} ) {
		$self->{$key} = $options->{$key}
	}	
	
	
	# We need to stash die_on_error in a global,
	# as error() is a class method (does not receive the object).
	$Die_on_error = 1
		if ($self->{'die_on_error'});
	
	
	
	# Create and initialize our voice device
	# We do this FIRST because if we open any files before we init Modem::Vgetty's FileHandle objects we're in trouble
	my $devFactory = VOCP::Device::Factory->new();
	
	my $deviceType = $self->{'voice_device_type'};
	
	my %voiceDevInit = (	'type' 		=> $deviceType, 
				'device'	=> $self->{'device'}, 
				'pvftooldir'	=> $self->{'pvftooldir'},
				'vocp' 		=> $self);
				
	if ($self->{'voice_device_params'} && ref $self->{'voice_device_params'})
	{
		while (my  ($key, $val) = each %{$self->{'voice_device_params'}})
		{
			$voiceDevInit{$key} = $val;
		}
	}
	$self->{'voicedevice'} = $devFactory->newDevice(%voiceDevInit)
					|| VOCP::Util::error("Could not create a device of type '$deviceType'");
	
	
	
	my $gConfigFile = $options->{'genconfig'} || $self->{'genconfig'};
	$self->read_config($gConfigFile)
		if ($gConfigFile);
	
	
	VOCP::Util::error("Can't create box factory because no inboxdir set!")
		unless ($self->{'inboxdir'});
	
	
	my $cid = $ENV{'CALLER_ID'} || '';
	my $cname = $ENV{'CALLER_NAME'} || '';
	my $called = $ENV{'CALLED_ID'} || '';
			
	$self->{'call'}->{'caller_id'} = $cid ;
	$self->{'call'}->{'caller_name'} = $cname;
	$self->{'call'}->{'called_id'} = $called;
		
	
	unless ($self->{'nocalllog'})
	{
		my $callLogger = $self->getCallLogger();
		
		
		if ($self->{'log_incoming'})
		{
			$callLogger->newMessage ( {
							'type'	=> $VOCP::Util::CallMonitor::Message::Type{'INCOMING'},
							'cid'	=> $cid,
							'cname'	=> $cname,
							'called' => $called,
							});
		
			$callLogger->logMessage();
		}
		
	}
	
	
	
	# The box Factory will be used to create instances of the various sub types 
	# of the VOCP::Box class
	$self->{'boxFactory'} = VOCP::Box::Factory->new($self->{'inboxdir'});

	$self->read_box_config()
		if (defined $self->{'boxconfig'} && ! $self->{'noboxes'});
	
	$self->create_default_box()
		unless (defined $self->{'boxes'}->{$Default_box});
	
	return 1;
}


sub getCID {
	my $self = shift;
	
	if ($self->{'call'} && 
		($self->{'call'}->{'caller_id'} || $self->{'call'}->{'caller_name'}))
	{
		my $cidInfo =  $self->{'call'}->{'caller_name'} ? $self->{'call'}->{'caller_name'} . ' ' : '';
		$cidInfo .= $self->{'call'}->{'caller_id'};
		
		return $cidInfo;
	}
	
	return undef;
	
}


sub getCallLogger {
	my $self = shift;
	
	return undef if ($self->{'nocalllog'});
	
	return $self->{'_callLogger'} if (defined $self->{'_callLogger'});
	
	$self->{'_callLogger'} =  VOCP::Util::CallMonitor::Logger->new( { 'logfile'	=> $self->{'call_logfile'} })
					|| return VOCP::Util::error("Could not create new CallMonitor::Logger object");
					
	return $self->{'_callLogger'};
	
}
		
		

=head2 read_config CONFFILE

Reads each line of CONFFILE, ignoring empty lines or those
beginning with '#'.

Each line consists of:
	A spaces B spaces C ...
with a maximum of four entries per line.  These entries are
inserted into the VOCP object, where each of A, B, C is treated
as a hash key and the final entry is the associated value. 

Paramaters passed to new() will override anything from the config
file.

Calls read_box_config() to configure the various boxes and command
shells, if boxconfig was set in new or the config file.

=cut

sub read_config {
	my $self = shift;
	my $conffile = shift; # optional
	
	$conffile ||= $self->{'genconfig'};
	
	return undef
		unless ($conffile);
	
	my $configHash = VOCP::Config::Simple::read($conffile);
	
	while (my ($key, $value) = each(%{$configHash}))
	{
		$self->{$key} = $value;
	} 
	
	return 1;
}


=head2 read_box_config BOXCONFFILE

 WARNING: This method is DEPRECATED 
          The new boxes.conf file is XML and is to be parsed
	  and written by the VOCP::Config::Box module.


Reads each line of BOXCONFFILE, ignoring empty lines or those
beginning with '#'.

Parses the file and calls create_box() for each line beginning with
'box'.  Box lines have the format:

box number message type password owner branch email autojump restricted

  If any of the boxes where command shells then the config
file also contains 'command' lines, which are setup calling command().
Command lines have the format:

command box selection return run 


=cut

sub read_box_config {
	my $self = shift;
	my $boxconf = shift; # optional
	
	$boxconf ||= $self->{'boxconfig'};
	
	
	return undef
		unless ($boxconf);
	
	
	VOCP::Util::log_msg("Reading box config: $boxconf")
		if ($main::Debug > 1);
		
	my $boxConfigObj = VOCP::Config::Box->new($boxconf);
	
	my $boxesHash = $boxConfigObj->toHash();
	print STDERR Dumper($boxesHash) if ($main::Debug > 1);
	my $commanddir = $self->{'commanddir'} || $VOCP::Vars::Defaults{'commanddir'};
	
	if ($boxesHash)
	{
		my @chars = ('a'..'z', '0'..'9', 'A'..'Z');
		while (my ($boxNumKey, $boxInitHash) = each %{$boxesHash})
		{
			next unless (ref $boxInitHash eq 'HASH');
			
			my %initArgs = %{$boxInitHash};
			$initArgs{'number'} = $boxNumKey;
			$initArgs{'commanddir'} = $commanddir;
			$initArgs{'password'} = join("", @chars[ map { rand @chars } (1 .. 5) ]) if ($self->{'usepwcheck'});
			
			my $newBoxObj = $self->{'boxFactory'}->newBox(%initArgs );
			if ($newBoxObj)
			{	
				$self->{'boxes'}->{$boxNumKey} = $newBoxObj;
			}
		}
		
		return 1;
	} 
	
	# XML box conf read failed... try old style box file
	VOCP::Util::error("Box config $boxconf is not in XML format - trying old format.");
	
}


sub get_box_object {
	my $self = shift;
	my $boxnum = shift;
	
	unless (defined $boxnum && $boxnum =~ m|^\d+$|)
	{
		VOCP::Util::log_msg("Must pass a numerical box number to get_box_details()");
		return undef;
	}
	
	return undef unless (defined $self->{'boxes'}->{$boxnum} );
	
	return $self->{'boxes'}->{$boxnum};
}
	
sub get_box_details {
	my $self = shift;
	my $boxnum = shift;
	my $untaint = shift; # optionally, untaint all data...
	my $addNones = shift;
	
	unless (defined $boxnum && $boxnum =~ m|^\d+$|)
	{
		VOCP::Util::log_msg("Must pass a numerical box number to get_box_details()");
		return undef;
	}
	
	return undef unless (defined $self->{'boxes'}->{$boxnum} );
	
	my $details = $self->{'boxes'}->{$boxnum}->getDetails();
	
	foreach my $key (keys %{$details})
	{
		$details->{$key} = 'none' unless (defined $details->{$key});
	}
	$details->{'boxnum'} = $details->{'number'};
	
	return $details;
		
	
}

sub get_box_command {
	my $self = shift;
	my $boxnum = shift;
	my $selection = shift;
	my $untaint = shift; # optionally, untaint all data...
	my $addNones = shift;
	
	
	VOCP::Util::error("Must pass a numerical box number to get_box_command()")
		unless (defined $boxnum && $boxnum =~ m|^\d+$|);
		
	VOCP::Util::error("Must pass a numerical selection to get_box_command()")
		unless (defined $selection && $selection =~ m|^\d+$|);
	
	return undef unless (defined $self->{'boxes'}->{$boxnum});
	
	my $select = $self->{'boxes'}->{$boxnum}->selection($selection);
	
	my $input = $select->{'input'};
	my $return =  $select->{'return'};
	my $run = $select->{'run'};
	
	my $defaultValue = ($addNones ? 'none' : "");
	$input ||= $defaultValue;
	$return ||= 'exit';
	$run ||= $defaultValue;
		
		
	if ($untaint)
	{
		VOCP::Util::error("Invalid key set for command box $boxnum, $selection: $selection")
			unless ($selection =~ m|^(\d+)$|);
		$selection = $1;
		
		VOCP::Util::error("Invalid input set for command box $boxnum, $selection: $input")
			unless ($input =~ m#^(|$VOCP::Box::Command::ValidInput)$#);
		$input = $1;
		
		VOCP::Util::error("Invalid return set for command box $boxnum, $selection: $return")
			unless ($return =~ m#^($VOCP::Box::Command::ValidReturn)$#);
		$return = $1;
		
		VOCP::Util::error("Invalid run set for command box $boxnum, $selection: $run")
			unless ($run =~ m|^(.*)$|); # Can be anything - better checks done before actual runs...
		$run = $1;
		
		
		
	}
	
	$run =~ s|$self->{'commanddir'}/||g;
	
	my $retHref =  {
				'selection'	=> $selection,
				'input'		=> $input,
				'return'	=> $return,
				'run'		=> $run,
			};
			
	return $retHref;
	
}

sub get_box_commands_list {
	my $self = shift;
	my $boxnum = shift;
	my $untaint = shift; # optionally, untaint all data...
	my $addNones = shift; # optionally, add 'none' when value is not set
	
	VOCP::Util::error("Must pass a numerical box number to get_box_commands()")
		unless (defined $boxnum && $boxnum =~ m|^\d+$|);
	
	return undef unless (defined $self->{'boxes'}->{$boxnum});
	
	my $type = $self->type($boxnum);
	VOCP::Util::error("Requesting commands for box of type '$type'")
		unless ($type eq 'command');
	
	my $selections = $self->{'boxes'}->{$boxnum}->getAllSelections();
	my @retList;
	foreach my $sel (@{$selections})
	{
		$retList[scalar @retList] = $self->get_box_command($boxnum, $sel->{'selection'}, $untaint, $addNones);
	
	} # end for each command key
	
	
	return \@retList;
}

sub get_box_list {
	my $self = shift;
	my $untaint = shift; # optionally, untaint all data...
	my $addNones = shift;
	
	my @boxList;
	
	foreach my $boxnum (sort keys %{$self->{'boxes'}})
	{
	
		$boxList[scalar @boxList] = $self->get_box_details($boxnum, $untaint, $addNones);
		
	}
	
	return \@boxList;
}



sub getBoxesAsHash {
	my $self = shift;
	
	my $retHash = {};
	my $boxList = $self->get_box_list('UNTAINT');
	
	foreach my $box (@{$boxList})
	{
		my $boxNum = $box->{'boxnum'};
		$retHash->{$boxNum} = $box;
		
		if ($box->{'type'} =~ m|^command$|i)
		{
			my $boxCommands = $self->get_box_commands_list($boxNum, 'untaint');
			foreach my $bCmd (@{$boxCommands})
			{
				my $selection = $bCmd->{'selection'};
				$retHash->{$boxNum}->{'commands'}->{$selection} = $bCmd;
			}
		} elsif ($box->{'type'} =~ m|^faxondemand$|i)
		{
			my $file2fax = $self->{'boxes'}->{$boxNum}->file2Fax();
			
			if (defined $file2fax)
			{
				$retHash->{$boxNum}->{'file2fax'} = $file2fax;
			}
		}
	} # end loop over all boxes.
	
	return $retHash;
}


				
sub delete_box {
	my $self = shift;
	my $boxnum = shift;

	
	VOCP::Util::error("Must pass a numerical box number to delete_box()")
		unless (defined $boxnum && $boxnum =~ m|^\d+$|);
	
	unless (defined $self->{'boxes'}->{$boxnum} )
	{
		
		VOCP::Util::log_msg("Unknown box number '$boxnum' passed to delete_box()");
		return undef;
	}
		
	
	
	VOCP::Util::log_msg("deleting box $boxnum")
		if ($main::Debug);
	
	delete $self->{'boxes'}->{$boxnum};
	
	return 1;
}



sub write_box_config {
	my $self = shift;
	my $output_file = shift;
	
	
	return VOCP::Util::error("Must pass an output file to VOCP::write_box_config")
		unless ($output_file);
	
	my $boxHash = {};
	while (my ($boxNum, $boxObj) = each %{$self->{'boxes'}})
	{
		$boxHash->{$boxNum} = $boxObj->getDetails();
	}
	
	my $boxConfig = VOCP::Config::Box->new();
	
	$boxConfig->fromHash($boxHash);
	my $resp = $boxConfig->writeConfig($output_file);
	my $group = $self->{'group'} || 'vocp';
	
	my ($name,$passwd,$uid,$gid,
                      $quota,$comment,$gcos,$dir,$shell,$expire) = getgrnam($group);
	my $shadowFile = "$output_file.shadow";
	if ($name && $name eq $group && -e $shadowFile)
	{
		chmod 0640, $shadowFile;
		chown $>, $uid, $shadowFile;
	}
	
	return $resp;
		
	####################### DEAD BEEF #####################
	### Legacy code below... This section is deprecated and will be removed
	###
	
	if (! open (OUTPUT, ">$output_file"))
	{
		return VOCP::Util::error("Could not open '$output_file' for write: $!");
	}
	
	my $header = qq|#### VOCP Box Configuration file ####|
		    .qq|#\n#\n#\n|
		    .qq|#\tboxes.conf, box config file of the VOCP voice messaging system.\n|
		    .qq|#\tCopyright (C) 2000 Patrick Deegan, http://www.psychogenic.com\n|
		    .qq|#\n#\n#\n|
		    .qq|#### This file was generated by VOCP        ####\n|
		    .qq|#### Please see the example config or the   ####\n|
		    .qq|#### www.VOCPsystem.com website for details ####\n|
		    .qq|#\n#\n#\n|
		    .qq|# Box configs, of the form:\n|
		    .qq|# 'box' num message type password owner branch email autojump  restricted\n|;

	
	my $boxConfContents = $header;
	my @commandBoxes;
	my @faxondemandBoxes;
	
	my $boxList = $self->get_box_list('UNTAINT', 'ADDNONES');
	
	foreach my $box (@{$boxList})
	{
		
		my $type = $box->{'type'};
		my $boxnum = $box->{'boxnum'};
		if ($type eq 'command')
		{
			$commandBoxes[scalar @commandBoxes] = $boxnum;
		} elsif ($type eq 'faxondemand')
		{
			$faxondemandBoxes[scalar @faxondemandBoxes] = $boxnum;
		}
		
		# 'box' num message type password owner  branch  email   autojump  restricted
		$boxConfContents .= "### BOX $boxnum\n"
					."box $boxnum\t$box->{'message'}\t$type\t$box->{'password'}\t$box->{'owner'}\t"
					."$box->{'branch'}\t$box->{'email'}\t$box->{'autojump'}\t$box->{'restricted'}\n#\n";
	}
	
	$boxConfContents .= "#\n#\n###Command box configs###\n"
				. "# form:\n# 'command' box selection input return run\n#\n" if (scalar @commandBoxes);
	
	foreach my $commandBoxNum (@commandBoxes) 
	{
		# Lines for command box config, form:
		#'command' box selection input	return run 
		
		next unless ($self->{'boxes'}->{$commandBoxNum}->numSelections());
		
		$boxConfContents .= "### Command box $commandBoxNum\n";
		
		foreach my $selection ( @{$self->{'boxes'}->{$commandBoxNum}->getAllSelections()} )
		{
			my $selnum = $selection->{'selection'};
			my $config = $self->get_box_command($commandBoxNum, $selnum, 'UNTAINT', 'addnones');
			my $input = $config->{'input'} || 'none';
			my $return = $config->{'return'} || 'exit';
			my $run = $config->{'run'};
			
			$boxConfContents .= "command $commandBoxNum\t$selnum\t$input\t$return\t$run\n";
		}
	}
	
	$boxConfContents .= "#\n#\n###Fax-on-Demand box configs###\n" 
				. "# form:\n# 'faxondemand' box fileToFax\n#\n" if (scalar @faxondemandBoxes);
	
	foreach my $faxondemandBoxNum (@faxondemandBoxes) 
	{
		# Lines for faxondemand box config, form:
		# 'faxondemand' box fileToFax
		next unless (defined $self->{'boxes'}->{$faxondemandBoxNum});
		
		my $file2fax = $self->{'boxes'}->{$faxondemandBoxNum}->file2Fax() || next;
		
		$boxConfContents .= "### faxondemand box $faxondemandBoxNum\n";
		$boxConfContents .= "faxondemand $faxondemandBoxNum\t$file2fax\n";
	}
	
	
			
	$boxConfContents .= "\n\n### END BOX CONFIG ###\n";	
		
	#print OUTPUT Dumper($self);
	
	print OUTPUT $boxConfContents;
	
	close(OUTPUT);
	
	return 1;
}


=head2 bad_box_definition BOXNUM %PARAMS

Attempts to create a box based on params.  Returns undef on success, returns an error
message otherwise.  In all cases, the state of the VOCP object remains unchanged (no boxes
are added to the list)

=cut

sub bad_box_definition {
	my $self = shift;
	my $boxnum = shift;
	my %params = @_;
	
	return "Invalid box.  Must pass numerical box to create." if ($boxnum !~ m|^\d+$|);
	
	eval {
		local $SIG{'__DIE__'} = sub { return $_[0];} ;
		$self->create_box($TestBoxNum, %params);
	};
	
	delete $self->{'boxes'}->{$TestBoxNum};
	
	if ($@) {
		my $ret = $@;
		$ret =~ s|$DEADBEEF|$boxnum|g;
		$ret =~ s|at .*line \d+||g;
		return $ret;
	}
	
	
	
	return undef;
}
			
	




=head2 create_box BOXNUM %PARAMS

Creates box (number BOXNUM) with parameters included in 
the PARAMS hash.

Valid PARAMS are:

	message
	type
	password
	owner
	branch
	email
	autojump
	restricted

BOXNUM, message and type are REQUIRED.  Other fields may be
required according to type.  Many fields will accept 'none'
as a valid entry (which they ignore) - this is used as a 
place holder in the boxconfig file.

If the box is neither a voicemail box, a pager or a command
shell and if no branching or auto_jump is setup, then the
dead_end() flag is set true.

=cut


sub create_box {
	my $self = shift;
	my $boxnum = shift;
	my %params = @_;
	
	$params{'number'} = $boxnum unless (defined $params{'number'});
	
	VOCP::Util::log_msg("Creating box $boxnum")
		if ($main::Debug > 1);
	
	VOCP::Util::error("Must pass a box number to create_box", $VOCP::Vars::Exit{'MISSING'})
		unless (defined $boxnum); # can be 000
		
	VOCP::Util::error("Trying to create box $boxnum: already exists!", $VOCP::Vars::Exit{'EXISTS'})
		if (defined $self->{'boxes'}->{$boxnum} && ! $params{'overwrite_box'});
	
	# Can't have same num as code to retrieve messages
	VOCP::Util::error("Box has the same number ($boxnum) as the login_num code", $VOCP::Vars::Exit{'EXISTS'})
		if ($boxnum eq $self->login_num());
	
	# Define the box (validation in box subs need it)
	$self->{'boxes'}->{$boxnum} = $self->{'boxFactory'}->newBox(%params);
	
	
	return 1;
	
}

# Default box is created when no other boxes were set up.
# The password is set to a random value, such that no
# system (however shabbily set up) has an accessible box
# for phreakers ;)
sub create_default_box {
	my $self = shift;
	
	# We create a default box.
	# For security, this box will accept messages
	# but the default password is random - it is
	# impossible to login without changing to something
	# better.
	
	my @chars = (0..9);
	
	$self->create_box($Default_box, 
				'password' => join("", @chars[ map { rand @chars } (1 .. 5) ]),
				'owner' => 'root',
				'type' => 'mail',
				'message' => 'standard.rmd')
		|| return undef;
	
	return 1;
	
}	

=head2

email_attachements [BOOL]

Returns wether VOCP is set to include the messages themselves as 
attachements when sending email notification.

This value is global and is set in vocp.conf

=cut

sub email_attachements {
	my $self = shift;
	my $value = shift ; #optional - sets
	
	$self->{'email_attach_message'} = $value
		if (defined $value);
	
	return $self->{'email_attach_message'} ;
}


=head2 

#########  Getting and setting the VOCP object attributes ########

=head2 voicedevice [DEVICE]

=cut

sub voicedevice {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{	
		my $type = ref $setTo;
		VOCP::Util::error("Must pass a VOCP::Device subclass object to voicedevice")
			unless ($type && $type =~ /^VOCP::Device/);
		
		$self->{'voicedevice'} = $setTo;
	}
	
	return $self->{'voicedevice'};
}

sub get_start_box {
	my $self = shift;
	my $startBoxOverride = shift; # optionally override
	
	VOCP::Util::log_msg("VOCP::get_start_box() Called.")
		if ($main::Debug > 1);
	
	
	if (defined $startBoxOverride && defined $self->{'boxes'}->{$startBoxOverride})
	{
		VOCP::Util::log_msg("VOCP::get_start_box() called with override - returning $startBoxOverride")
			if ($main::Debug);
		
		return $startBoxOverride;
	}
	
	my $startBox = $VOCP::Default_box;
	
	# The root box may be set in vocp.conf with the 'rootbox' option.
	# The root box may also be overridden on a per-device basis, by using
	# rootbox_ttySX entries.
	if (defined $self->{'deviceID'})
	{
		my $startboxOverride = "rootbox_" .  $self->{'deviceID'};
		if (defined $self->{$startboxOverride})
		{
			$startBox = $self->{$startboxOverride};
		} elsif (defined $self->{'rootbox'})
		{
			$startBox = $self->{'rootbox'};
		}
	} elsif (defined $self->{'rootbox'})
	{
			$startBox = $self->{'rootbox'};
	}
	
	unless ($self->{'callid_filter'} && $self->{'call'}->{'caller_id'} 
			&& $self->{'call'}->{'caller_id'} ne 'none')
	{
		VOCP::Util::log_msg("VOCP::get_start_box() No CID info or 'callid_filter' not set, returning default box")
			if ($main::Debug);
			
		return $startBox;
	}
	
	VOCP::Util::error("VOCP::get_start_box() 'callid_filter' set but file '$self->{'callid_filter'}' not found or unreadable")
		unless (-e $self->{'callid_filter'} && -r $self->{'callid_filter'});
	
	my $cid = $self->{'call'}->{'caller_id'};
	my $cidFilterConfig = VOCP::Config::Simple::read($self->{'callid_filter'});
	
	unless ($cidFilterConfig)
	{
		return VOCP::Util::error("VOCP::get_start_box() could not get config from $self->{'callid_filter'}");
	}
	
	while (my ($key, $value) = each(%{$cidFilterConfig}))
	{
		VOCP::Util::log_msg("Checking if '$cid' matches '$key'")
			if ($main::Debug > 1);
			
		if ($cid =~ m!$key!i)
		{
			if ($value =~ m/\d/)
			{	
			
				VOCP::Util::log_msg("Found a match for '$cid', setting destination to $value")
					if ($main::Debug);
					
				return $value;
			} else {
				VOCP::Util::log_msg("Call from $cid matched cid filter '$key' but no destination set!");
			}
		}
	}
		
	return $startBox;
}
		
	
		
	
	
=head2 current_box [BOXNUM]

Returns the currently selected box number.  If 
BOXNUM is defined, the current box is set to 
BOXNUM before being returned.

=cut

sub current_box {
	my $self = shift;
	my $boxnum = shift; #optional - sets
	
	if (defined $boxnum) { # We're setting
		# Check it
		VOCP::Util::error("Trying to set current_box to $boxnum but no such box exists")
			unless (defined $self->{'boxes'}->{$boxnum} );
	
		# Set it
		$self->{'current_box'} = $boxnum;
	}
	
	return $self->{'current_box'};

}


=head2 type [BOXNUM [TYPE]]

Returns the type of BOXNUM or the current_box().
If BOXNUM and TYPE are set, BOXNUM\'s type is set
to TYPE, after validation.

Acceptable TYPEs are:

	mail
	pager
	command
	faxondemand
	none (ignored, used as placeholder in conf file)

Validation:

mail 	must have a password set.

pager	must have an email set.

faxondemand - only needs to be configured in boxes.conf to set fileToFax

command	must have a password and an owner set.

Note: When setting type to 'mail', is_mailbox() is set to
true.


=cut
	
sub type {
	my $self = shift;
	my $boxnum = shift; #optional
	# my $type = shift; #optional - sets
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
		
	return $self->{'boxes'}->{$boxnum}->type();
	
}

=head2 is_mailbox [BOXNUM [IS] ]

Returns wheter BOXNUM (or current_box()) is
of a (voice)mailbox.

If BOXNUM and IS are set, sets the value
of is_mailbox.

Note: This is a convenience function, you could
just call type() and see if it eq 'mail'.  is_mailbox()
is set to true when setting type to 'mail'.

=cut

sub is_mailbox {
	my $self = shift;
	my $boxnum = shift; #optional
	my $is = shift; #optional - sets
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
	
	$self->{'boxes'}->{$boxnum}->isMailbox($is)
		if (defined $is); #May be true of false
	
	#Check that it has a password if it is a mailbox
	if ($is && (! $self->password($boxnum)) ) { 
		VOCP::Util::error("Box $boxnum: is_mailbox cannot be true "
				. "without a password", $VOCP::Vars::Exit{'MISSING'});
	}
	
	
	return $self->{'boxes'}->{$boxnum}->isMailbox();
	
}


=head2 owner [BOXNUM [OWNER]]

Returns the owner of BOXNUM or the current_box().
If BOXNUM and OWNER are set, BOXNUM\'s owner is set
to OWNER.

Acceptable OWNERs are:

	system user (username from /etc/passwd)
	none (ignored, used as placeholder in conf file)

=cut

sub owner {
	my $self = shift;
	my $boxnum = shift; #optional
	my $owner = shift;  #optional - sets
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});

	$self->{'boxes'}->{$boxnum}->owner($owner)
		if ($owner);
	
	return $self->{'boxes'}->{$boxnum}->owner();
	
}

=head2 email [BOXNUM [EMAIL]]

Returns the email of BOXNUM or the current_box().
If BOXNUM and EMAIL are set, BOXNUM\'s email is set
to EMAIL.

Note: No validation is done on the email address.
The addr will be used to email the user notification
of new voice mail messages or pager messages, using
the (/bin/mail type) program set in the configuration
file, as

programs	mail	/path_to/mail_program

=cut

sub email {
	my $self = shift;
	my $boxnum = shift; #optional
	my $email = shift;  #optional - sets
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});

	$self->{'boxes'}->{$boxnum}->email($email)
		if ($email && ($email ne 'none'));
	
	return $self->{'boxes'}->{$boxnum}->email();
	
}



sub name {
	my $self = shift;
	my $boxnum = shift; #optional
	my $name = shift;  #optional - sets
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $boxnum && defined $self->{'boxes'}->{$boxnum});

	$self->{'boxes'}->{$boxnum}->name($name)
		if ($name && ($name ne 'none'));
	
	return $self->{'boxes'}->{$boxnum}->name();
	
}


=head2 auto_jump [BOXNUM [JUMPTO]]

Returns the auto_jump of BOXNUM or the current_box().
If BOXNUM and JUMPTO are set, BOXNUM\'s auto_jump is set
to JUMPTO.

Note: You can only set auto_jump on boxes which would
otherwise be dead ends (i.e. NOT mail/pager/command boxes,
nor those with branching set).


=cut

sub auto_jump {
	my $self = shift;
	my $boxnum = shift; #optional
	my $jumpto = shift;  #optional - sets
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
		
	if (defined $jumpto && $jumpto ne 'none') { # We are trying to set auto_jump

		$self->{'boxes'}->{$boxnum}->autojump($jumpto);
			    
		
	}
	
	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
	
	return $self->{'boxes'}->{$boxnum}->autojump();
	
}

=head2 dead_end [BOXNUM [IS]]

Returns the dead_end of BOXNUM or the current_box().
If BOXNUM and IS are set, BOXNUM\'s dead_end is set
to IS.

Note: dead_end is set to true when creating a box which is
neither a mail/pager/command box and does not have auto_jump 
or branching set up.

=cut

sub dead_end {
	my $self = shift;
	my $boxnum = shift; #optional
	my $isdeadend = shift;  #optional - sets
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
	
	$self->{'boxes'}->{$boxnum}->isDeadEnd($isdeadend)
		if (defined $isdeadend);
	
	return $self->{'boxes'}->{$boxnum}->isDeadEnd();
	
}

=head2 message [BOXNUM [MSG]]

Returns the message associated with BOXNUM or the current_box().
If BOXNUM and MSG are set, BOXNUM\'s message is set
to MSG.

=cut

sub message {
	my $self = shift;
	my $boxnum = shift;
	my $msg = shift; #optional (sets)
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});


	if ($msg && $msg ne 'none') { # We are setting the message
	
		my $file = VOCP::Util::full_path($msg, $self->{'messagedir'});
		
		$self->{'boxes'}->{$boxnum}->message($file);
		
	}
			
	return $self->{'boxes'}->{$boxnum}->message();

}

=head2 password [BOXNUM [PASSWD]]

Returns the password associated with BOXNUM or the current_box().
If BOXNUM and PASSWD are set, BOXNUM\'s password is set
to PASSWD.

This password is used when:

	- Retrieving messages for voicemail boxes
	- Accessing the command shell for command boxes.


Note: Avoid using passwords == 0

=cut

sub password {
	my $self = shift;
	my $boxnum = shift;
	my $passwd = shift; # optional - sets
	
	return undef
		unless (defined $self->{'boxes'}->{$boxnum});
	
	# Special case - 'none' in config means no password
	return undef
		if ($passwd && ($passwd eq 'none') );
	
	if (defined $passwd) { # Setting passwd
	
		$self->{'boxes'}->{$boxnum}->password($passwd);
	}
	
	return $self->{'boxes'}->{$boxnum}->password();
	
}

=head2 check_password BOXNUM APASSWORD

Checks if :

	APASSWORD is equal to the password
	APASSWORD crypted is equal to the (crypted) password
	APASSWORD is dtmf text input and equal to password
	APASSWORD is dtmf text input and, when crypted, equal to (crypted) password
	
Returns true when there is a match, false otherwise.

=cut

sub check_password {
	my $self = shift;
	my $boxnum = shift;
	my $try = shift || "";
	
	return undef
		unless (defined $self->{'boxes'}->{$boxnum});
	
	if ($self->{'usepwcheck'})
	{
		my $pwcheckExec = $VOCP::Vars::Defaults{'vocplocaldir'} . '/bin/pwcheck';
		unless (-e $pwcheckExec && -x $pwcheckExec)
		{
			
			$pwcheckExec = $VOCP::Vars::Defaults{'vocplocaldir'} . '/bin/pwcheck.pl';
			unless (-e $pwcheckExec && -x $pwcheckExec)
			{
				return VOCP::Util::error("check_password(): 'usepwcheck' is set but can't find suitable executable.");
			}
		}
		
		my $pwcheck = VOCP::PipeHandle->new();
		
		
		$pwcheck->open("| $pwcheckExec")
			|| return VOCP::Util::error("Can't open $pwcheckExec for write $!");
		
		$pwcheck->print("$boxnum $try\n");
		
		$pwcheck->close();
		my $exitStatus = $?;
		
		VOCP::Util::log_msg("Ran '$pwcheckExec' and got exit status '$exitStatus'")
			if ($main::Debug);
		
		return 1 if ($exitStatus == 0); # horray
		
		return 0; # failed 
	}
	
	return $self->{'boxes'}->{$boxnum}->checkPassword($try);
	
	
}


=head2 restricted BOXNUM [PASSWD]

Returns the password associated with the restricted box BOXNUM.
If BOXNUM and PASSWD are set, BOXNUM\'s restricted access password
is set to PASSWD.

restricted is distinct from password() in that it applies to those
who wish to leave a message or pager notification.

Boxes with restricted set will be inaccessible to users without the
password, thus only those with the correct password will be able
to leave messages.

Note: Avoid using passwords == 0

=cut

sub restricted {
	my $self = shift;
	my $boxnum = shift;
	my $passwd = shift; # optional - sets
	
	return undef
		unless (defined $self->{'boxes'}->{$boxnum});
	
	# Special case - 'none' in config means no password
	return undef
		if ($passwd && $passwd eq 'none');
	
	if (defined $passwd) { # Setting passwd
		
		$self->{'boxes'}->{$boxnum}->restricted($passwd);
	}
	
	return $self->{'boxes'}->{$boxnum}->restricted();
	
}

=head2 valid_box SELECTION

Checks that SELECTION is valid and returns the associated box
number.

SELECTION is valid if:

	CONDITION			RETURNED VALUE
	
	- It is the number of an	SELECTION 
	existing box
	
	- It is a valid branch		box associated with SELECTION
	
	- It is the number for		SELECTION
	message retrieval or
	command shells

If no user input was detected and default_branch_to is set to a true value,
then valid_box() will attempt to retrieve branch default_branch_to and return
that boxnumber, if applicable.


=cut

sub valid_box {
	my $self = shift;
	my $selection = shift;
	
	
	if ($main::Debug)
	{
		my $printSel = defined $selection ? $selection : '';
		
		VOCP::Util::log_msg("VOCP::valid_box() Checking if selection '$printSel' leads to a valid box");
	}
		

	my $default_branch = $self->default_branch_to();

	return undef
		unless (defined $selection || $default_branch);

	my $boxnum ;
	#May be a request to retreive messages
	#or for a command shell
	if ($selection eq $self->login_num()) {
	
		$boxnum = $selection;
		
	} elsif ($selection =~ /\d{2,}/) { # an actual mailbox
	
		$boxnum = $selection
			if (defined $self->{'boxes'}->{$selection});
		
	} elsif ($selection =~ /\d/) { # may be a branch
	
		$boxnum = $self->get_branch($selection);
		
	} elsif (! $selection) {
		VOCP::Util::log_msg("No input, checking for default_branch_to")
			if ($main::Debug > 1);  

		if ($default_branch) { #default is set
			VOCP::Util::log_msg("Using default_branch_to ($default_branch) as user input")
				if ($main::Debug);

			$boxnum = $self->get_branch($default_branch);
		} else { # No selection and no default
			VOCP::Util::log_msg("VOCP::valid_box() No selection and no default.")
				if ($main::Debug);
			return undef;
		}
	}	
	
	VOCP::Util::log_msg("VOCP::valid_box() Returning boxnum '$boxnum'")
		if ($boxnum && $main::Debug > 1);
	
	
	return $boxnum;
	
}

sub delete_command {
	my $self = shift;
	my $boxnum = shift;
	my $selection = shift;
	
	return undef unless (defined $self->{'boxes'}->{$boxnum});
	
	if (defined $selection) {
		VOCP::Util::log_msg("Deleting command selection $selection for box $boxnum")
			if ($main::Debug);
			
		$self->{'boxes'}->{$boxnum}->deleteSelection($selection);

	} else {
		VOCP::Util::log_msg("Deleting ALL command selections for box $boxnum")
			if ($main::Debug);
		$self->{'boxes'}->{$boxnum}->deleteAllSelections();
	}
	return 1;
}

sub bad_command_definition {
	my $self = shift;
	my $boxnum = shift;
	my $selection = shift;
	my $input = shift; 
	my $return = shift; 
	my $run = shift;
	
	VOCP::Util::log_msg("bad_command_definition(): Checking\n$boxnum,$selection,$input,$return,$run\n")
		if ($main::Debug > 1);
	
	return "Invalid box.  Must pass numerical box to command()." if ($boxnum !~ m|^\d+$|);
	return "Invalid selection. Must pass numerical selection to command()" if ($selection !~ m|^\d+$|);
	
	
	
	eval {
		local $SIG{'__DIE__'} = sub { return $_[0];} ;
		$self->command($boxnum,$TestBoxNum,$input,$return,$run);
		
	};
	
	$self->delete_command($boxnum, $TestBoxNum);
	
	if ($@) {
		my $ret = $@;
		$ret =~ s|$DEADBEEF|$selection|g;
		$ret =~ s|at.* line \d+||g;
		return $ret;
	}
	
	
	VOCP::Util::log_msg("bad_command_definition(): Check successful\n")
		if ($main::Debug > 1);
	
	return undef;
}
	


=head2 command [BOXNUM [SELEC [INPUT RETURN RUN]]]

Without parameters, returns whether BOXNUM or current_box()
has any commands set.

If BOXNUM and SELEC are passed, returns the command to run
for command box BOXNUM, selection (user input) SELEC.

If BOXNUM, SELEC, INPUT, RETURN and RUN are all passed, sets the
command to run (RUN), the input to expect (INPUT - none, raw or text)
and the return type (RETURN - output or exit value) for selection 
SELEC in box BOXNUM.

Valid values for RUN

	any program relative to commanddir.
	
Valid values for INPUT

	none. Program will not ask for any input.
	
	raw. Program will ask for input and pass digits to 
	RUN as the last command line option.

	text. Will treat DTMF input as text - see dtmf_to_text()
	for details.

Valid values for RETURN

	exit (default, will read the exit status of the call to RUN)

	output (will read the - numerical - value output by RUN)

This method calls command_input() to set the input type and 
command_return() to set the return value
to RETURN, when setting up the command.

=cut

sub command {
	my $self = shift;
	my $boxnum = shift;
	my $selection = shift; #opt
	my $input = shift; #optional - can be 'none', 'raw' or 'text'
	my $return = shift; # optional - can be 'exit', 'output' or 'file'
	my $run = shift; #optional
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
		
	
	if ($run) { #We are setting it
		
		$self->{'boxes'}->{$boxnum}->selection($selection, $input, $return, $run);
	}

	if (defined $selection) { #We want the command for a particular selection
	
		my $cmd = $self->{'boxes'}->{$boxnum}->selection($selection) || return undef;
		
		return $cmd->{'run'};
		
	} else { #We just want to know if any selections are set
		return $self->{'boxes'}->{$boxnum}->numSelections();	
	}
	
}



sub delete_command_selection {
	my $self = shift;
	my $boxnum = shift;
	my $selection = shift; #opt


	return undef 
		unless (defined $boxnum && defined $selection && defined $self->{'boxes'}->{$boxnum});
		
	return $self->{'boxes'}->{$boxnum}->deleteSelection($selection);
	
}


=head2 script [BOXNUM [FILE INPUT RETURN]]

=cut

sub script {
	my $self = shift;
	my $boxnum = shift;
	my $file = shift; #opt
	my $input = shift;
	my $return = shift;
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
		
	
	my $type = $self->type($boxnum);
	
	VOCP::Util::error("VOCP::script() Trying to access script on box of type '$type'")
		unless ($type eq 'script');
	
	
	if ($file) { #We are setting it
		$self->{'boxes'}->{$boxnum}->script($file);
		$self->{'boxes'}->{$boxnum}->input($input);
		$self->{'boxes'}->{$boxnum}->return($return);
		
		
	}
	
	
	return $self->{'boxes'}->{$boxnum}->script();	
	
}
	


=head2 faxondemand [BOXNUM [FILE]]

Gets (and optionally sets, if FILE arg is passed) the fax file to send for this
faxondemand box (BOXNUM, if passed, current_box() otherwise).

=cut

sub faxondemand {
	my $self = shift;
	my $boxnum = shift;
	my $file = shift; #opt
	
	$boxnum ||= $self->current_box();

	return undef 
		unless (defined $self->{'boxes'}->{$boxnum});
		
	
	if ($file) { #We are setting it
		$self->{'boxes'}->{$boxnum}->file2Fax($file);	
	}
	
	
	return $self->{'boxes'}->{$boxnum}->file2Fax();	
	
}



=head2 command_input BOXNUM SELEC [TYPE]

With only BOXNUM and SELEC passed, returns the type of input value
to expect/get from user (either none, raw or text input).

If BOXNUM, SELEC and TYPE are all passed, sets the
input type for selection SELEC in box BOXNUM.

Types:
 
	none. Do not ask for any input.
	
	raw. Ask for input and pass digits to 
	RUN as the last command line option.

	text. Will treat DTMF input as text - see dtmf_to_text()
	for details.


=cut


sub command_input {
	my $self = shift;
	my $boxnum = shift;
	my $selection = shift;
	
	return undef
		unless (defined $selection && defined $self->{'boxes'}->{$boxnum});
				

	my $cmd = $self->{'boxes'}->{$boxnum}->selection($selection) || return undef;
		
	return $cmd->{'input'};
	
}




=head2 command_return BOXNUM SELEC [RETURN]

With only BOXNUM and SELEC passed, returns the type of return value
to read to user (either the exit code or the numerical output of 
the command).

If BOXNUM, SELEC and RETURN are all passed, sets the
return type (RETURN - output or exit value) for selection SELEC in box
BOXNUM.


=cut

sub command_return {
	my $self = shift;
	my $boxnum = shift;
	my $selection = shift;
	
	return undef
		unless (defined $selection && defined $self->{'boxes'}->{$boxnum});
	
	my $cmd = $self->{'boxes'}->{$boxnum}->selection($selection) || return undef;
	
	return $cmd->{'return'};
}

=head2 get_branch [SELEC [BOXNUM]]

Returns the branch box for selection SELEC, for box BOXNUM or 
the current_box(). If SELEC not set, returns the number of possible branches

Note:  This sub has a parameter order which is different than most others - notice
that BOXNUM is last, instead of first as usual.

A note on branching:
A box has branching set up when it is created with create_box().  Branching entries
in the boxconfig file are comma seperated lists of boxes.  

There are two methods for setting up branching in the config file:

XXX,YYY,ZZZ

The user\'s choice and the 
corresponding box are set according to the order of the boxes.  For example, if the
configuration file has a box with the branching paramater set to '011,132,012' then the
user will be directed to box 011 for selection (SELEC) 1, to box 132 if he presses '2' or
box 012 if he presses '3'.


N=XXX,M=YYY,O=ZZZ
The user's selection and the corresponding box are set by the N,M,O... values.  For example,
1=100,2=200,9=001 would bring the user to box 100 after pressing 1, box 200 after pressing 2 and
box 001 (the root box) after pressing 9.  This is useful if you wish to always keep a certain box
associated with some high-valued key as it avoids having to fill in all the preceding entries.


You may use a mix of N=XXX and simple YYY entries - be careful not to have something like:
100,3=200,500 
as the 3 key will lead to box 500 (3=200 is overwritten with a warning in the log file).


=cut

sub get_branch {
	my $self = shift;
	my $selec = shift; # optional
	my $boxnum = shift; #optional
	
	$boxnum ||= $self->current_box() || $Default_box;
	
	VOCP::Util::log_msg("VOCP::get_branch() Called with selection '$selec' in box $boxnum")
		if ($main::Debug > 1);
	
	return undef
		unless (defined $self->{'boxes'}->{$boxnum});
	
	unless (defined $selec) { # No selec, return number of branches
		
		return $self->{'boxes'}->{$boxnum}->numBranch();
	}
	
	return $self->{'boxes'}->{$boxnum}->branch($selec);
	
}


=head2 default_branch_to [DEFAULT]

If the default branch is set to a positive integer, when a box has branching set
and the user does NOT enter any selection, the system will act as if the user had
entered the default_branch_to (set in the call to new() or the general config file)
and will go to that box, if it is valid.

If DEFAULT is a defined numeric value, default_branch_to will be set to DEFAULT.

=cut


sub default_branch_to {
	my $self = shift;
	my $boxnum = shift; #optional
	my $default_branch = shift; #optional

	$boxnum ||= $self->current_box() || $Default_box;

	# We are setting the value
	if (defined $default_branch) {
		VOCP::Util::error("Trying to set default_branch_to to invalid value: $default_branch")
			unless ($default_branch =~ /^\d+$/);

		$self->{'default_branch_to'} = $default_branch;
	}

	return undef 
		unless (defined $self->{'default_branch_to'});

	return $self->{'default_branch_to'};

}





=head2 login_num [NUM]

Returns the special "boxnumber" used to indicate the desire to enter message
retrieval mode or a command shell.

If NUM is defined (and is valid DTMF - digits), the retrieve num is set to NUM.

=cut

sub login_num {
	my $self = shift;
	my $num = shift; # optional - sets
	
	$self->{'login_num'} = $num
		if (defined $num && $num=~ /^[\d#\*]+$/);
		
	return $self->{'login_num'};
	
}


=head2 getAttachmentFormat

Returns the type of voicemail that gets attached to the email (such as wav or mp3).
Defaults to 'wav' if not set.

=cut
sub getAttachmentFormat {
        my $self = shift;
        return($self->{'message_in_email_format'} || 'wav');  
}


=head2 create_attachement MSGFILENAME ATTACHEMENT_FORMAT [BASE64ENCODE]

Creates and return (an optionally Base64 encoded) string in format
ATTACHEMENT_FORMAT from the MSGFILENAME rmd file.

=cut


sub create_attachment {
	my $self = shift;
	my $msg = shift || VOCP::Util::error("Must pass a message filename to create_attachment");
	my $attachmentFormat = shift || VOCP::Util::error("Must pass an attachment format (ogg,mp3,wav) to create_attachment");
	my $base64encode = shift; # optionally, base64 encode.
	
	
	return VOCP::Util::rmd2attachment( 	'inputfile'	=> $msg,
						'outputformat'	=> $attachmentFormat,
						'base64encode'	=> $base64encode,
						'rmdsample'	=> $self->{'rmdsample'},
						'pvftooldir'	=> $self->{'pvftooldir'},
						'tempdir'	=> $self->{'tempdir'},
					);
}


=head2 send_email BOXNUM [MSG [ATTACHBASE64]]

Sends MSG (or default "You have a new voicemail message for 
box BOXNUM") to BOXNUM email addresse, with the subjet set
in the genconfig file or in new with 'email_subject'.

BOXNUM must have an email set.  The mail program used is set
in the genconfig file with the 'programs email xxx' option, 
which must be a program that acts as the standard Un*x /bin/mail
or mailx programs.

=cut

sub send_email {
	my $self = shift;
	my $boxnum = shift; # optional
	my $msg = shift;#optional
	my $attachbase64 = shift || 0; #optional 
	my %params = @_;
	
	VOCP::Util::log_msg("About to send email")
		if ($main::Debug);
	
	VOCP::Util::error("VOCP::send_mail: Give me a boxnumber to email to.", $VOCP::Vars::Exit{'MISSING'})
		unless (defined $boxnum);
	
	VOCP::Util::error("No valid mail program set for VOCP::send_mail", $VOCP::Vars::Exit{'MISSING'})
		unless (-x $self->{'programs'}->{'email'});
	
	$boxnum ||= $self->current_box();	
	
	VOCP::Util::error("No such box ($boxnum) in VOCP::send_mail", $VOCP::Vars::Exit{'MISSING'})
		unless (defined $self->{'boxes'}->{$boxnum});
	
	my $to = $self->{'boxes'}->{$boxnum}->email() 
		|| VOCP::Util::error("No email set for box ($boxnum) in VOCP::send_mail", $VOCP::Vars::Exit{'MISSING'});
	
	my $subject = $params{'subject'} || $self->{'email_subject'} || 'VOCP Voicemail';
	my $text = $params{'text'} || "You have a new voicemail message for box $boxnum";
	
	VOCP::Util::log_msg("Sending to box $boxnum: '$msg'")
		if ($main::Debug > 1);
	
	my $fromAddr = $self->{'email_from_address'} || 'vocp@localhost.localdomain';
	my $from = "VOCP Voicemail <$fromAddr>";
	
	my $email;
	if ($attachbase64)
	{
		
		
		my $attachmentFormat = $self->getAttachmentFormat();
		my $attach = $self->create_attachment($msg, $attachmentFormat, 'BASE64ENCODE');
		
		## MP3 Support mods by Ali Naddaf begin here...
		$email = VOCP::Util::create_email($from, $to, 
							$subject, $text, $attach, $attachmentFormat);
		## END Ali Naddaf MP3 Support mods

	} else
	{
		$email = VOCP::Util::create_email($from, $to, $subject, $msg || $text);
	}
	
	VOCP::Util::log_msg("SENDING Message: \n*****\n$email\n*****\n")
			if ($main::Debug > 1);
	
	my $mailfh = VOCP::PipeHandle->new();
	
	$mailfh->open("| $self->{'programs'}->{'email'} $to")
		|| VOCP::Util::error("Can't open $self->{'programs'}->{'email'} for write: $!");
	
	#open (MAIL, "| $self->{'programs'}->{'email'} $to")
	#	|| VOCP::Util::error("Can't open $self->{'programs'}->{'email'} for write: $!");
	
	$mailfh->print($email);
	
	$mailfh->close();
	
	#close (MAIL)
	#	|| VOCP::Util::log_msg("$self->{'programs'}->{'email'} did not close nicely $!");
	
	VOCP::Util::log_msg("Email sent to box $boxnum");
	
	return 1;
	
}


=head2 send_faxondemand BOXNUM [FILE]



=cut

sub send_faxondemand {
	my $self = shift;
	my $boxnum = shift || $self->current_box(); # optional
	my $msg = shift;#optional
	
	my $type = $self->type($boxnum);
	VOCP::Util::error("Requested faxondemand from box of type '$type' (num $boxnum)") if ( $type ne 'faxondemand');
	
	my $fileToFax = $self->faxondemand($boxnum) 
				|| VOCP::Util::error("Requested faxondemand from box $boxnum - but not fileToFax set.");
	
	VOCP::Util::log_msg("About to send fax '$fileToFax' for box $boxnum")
		if ($main::Debug);
	
	my $faxboxmessage = $self->message($boxnum);

	if ($faxboxmessage && $faxboxmessage ne 'none')
	{
		$self->{'voicedevice'}->play($faxboxmessage);
	
	}
	
	return $self->{'voicedevice'}->sendImage($fileToFax);
	
	
}


=head2 receiveFax

Receive a fax - normally handled by someone else, will exit the voice shell.

=cut

sub receiveFax {
	my $self = shift;
	
	$self->{'voicedevice'}->receiveImage();
	
}



sub deliveryAgent {
	my $self = shift;
	
	return $self->{'deliveryAgent'} if ($self->{'deliveryAgent'});
	
	my $options = {
		'genconfig'	=> $self->{'genconfig'} || $VOCP::Vars::DefaultConfigFiles{'genconfig'},
		'boxconfig'	=> $self->{'boxconfig'} || $VOCP::Vars::DefaultConfigFiles{'boxconfig'},
		'vocp'		=> $self,
	};
	
	
	$self->{'deliveryAgent'} = VOCP::Util::DeliveryAgent->new($options)
				|| VOCP::Util::error("VOCP::Util::deliveryAgent() Could not create a new VOCP::Util::DeliveryAgent object!");
	

	return $self->{'deliveryAgent'};
	
}
	
	

=head1

########  Playing and recording messages ########

=head2 record_message [BOXNUM]

BEEPs the user and records a voicemail message for BOXNUM 
(or current_box()).

The rmd file is created in 'inboxdir' (set in genconfig or
with call to new). The naming convention for recorded messages
is 'BOXNUM-MESSAGENUM.rmd' where MESSAGENUM is incremented by
1 for each new message and has at least 4 digits (i.e. message
1 for BOXNUM 200 will be named 200-0001.rmd).

If owner() is set for box BOXNUM and is a valid system user, 
the file is chowned to owner().  If 'group' option is set to a 
valid system group (say 'nobody'), then all files belong to group
'group' and the mode is 0640 else the file is only ledgible by the
owner (mode 0600).

Pressing a DTMF key during the process will stop recording.

=cut

sub record_message {
	my $self = shift;	
	my $boxnum = shift; #optional, defaults to curent
	
	# Get the boxnumber
	$boxnum ||= $self->current_box();
	
	# Verify it
	my $box = $self->valid_box($boxnum);
	
	VOCP::Util::error("No box number or invalid box ($boxnum) to record to!", $VOCP::Vars::Exit{'MISSING'})
		unless (defined $box);

	VOCP::Util::log_msg("About to record message for box $box")
		if ($main::Debug);
	
	
	my $baseName = $self->{'tempdir'} || '/tmp';
	$baseName .= "/vocpmsg$$";
	
	my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseName);
	
	unless ($tmpFileHandle && $tmpFileName)
	{
		VOCP::Util::error("VOCP::record_message() Could not create a temp file based on '$baseName'");
	}
	
	
	# Start recording
	VOCP::Util::log_msg("Recording message to box $box")
		if $main::Debug;
	
	$self->{'voicedevice'}->beep();
	
	my $oldmask = umask oct('0027');
	
	unlink $tmpFileName;
	$tmpFileHandle->close();
	#my $message = VOCP::Util::full_path($self->{'boxes'}->{$box}->createNewMessageName(), $self->{'inboxdir'});
	
	$self->{'voicedevice'}->record($tmpFileName);
	
	unless (-r $tmpFileName)
	{
		VOCP::Util::error("VOCP::record_message() - tried to record to '$tmpFileName' but can't find file after record.");
	}
	
	$tmpFileHandle = FileHandle->new();
	if (! $tmpFileHandle->open("<$tmpFileName"))
	{
		VOCP::Util::error("VOCP::record_message() - could not open '$tmpFileName' $!");
	}
	
	my $voiceMessageData = join('', $tmpFileHandle->getlines()); 
	my $voiceDataFormats = $self->{'voicedevice'}->validDataFormats();
	unlink $tmpFileName;
	$tmpFileHandle->close();
	
	my $deliveryAgent = $self->deliveryAgent() || VOCP::Util::error("VOCP::record_message() Could not get a VOCP::Util::DeliveryAgent object");
	
	
	my $deliveredMessages;
	my %messageMetaInfo = (
				'source'	=> 'phone',
			);
	if ($self->{'call'}->{'caller_id'} || $self->{'call'}->{'caller_name'})
	{
		my $cidData = $self->{'call'}->{'caller_id'} .  ' ' . $self->{'call'}->{'caller_name'};
		VOCP::Util::log_msg("VOCP::record_message() Appending CID data ($cidData) to message meta info")
			if ($main::Debug);
			
		$messageMetaInfo{'from'} = $cidData;
	}
	
	if ($self->is_mailbox($box))
	{
		# Use the delivery agent to deliver the message.  Notice that since this message
		# was just recorded by the voicedevice, we assume it is in some valid data format
		# and just use the 0th element of the list (which is sure to exist)
		$deliveredMessages = $deliveryAgent->deliverData($box, $voiceMessageData, $voiceDataFormats->[0],%messageMetaInfo);
		$self->{'boxes'}->{$box}->refresh();
		VOCP::Util::log_msg("Voice message delivered to box $box");
		if ($self->{'call_logfile'} && (! $self->{'nocalllog'}))
		{
			my $callLogger = $self->getCallLogger();
		
			$callLogger->newMessage( {
								'type'	=> $VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'},
								'boxnum'	=> $box,
								});
			$callLogger->logMessage();
		}
	
	} elsif ($self->type($box) eq 'group') {
	
		# Group boxes are like mailing lists, messages end up in boxes of all members.  Members may be other group
		# boxes, so we recurse (intelligently, to avoid loops) in getGroupMemberList() to get all final destinations.
		$self->{'_groupSearchSeen'} = {};
		my $members = $self->getGroupMemberList($box);
		delete $self->{'_groupSearchSeen'};
		
		unless (scalar @{$members})
		{
			VOCP::Util::error("VOCP::record_message() - No members in group box $box");
		}
		
		$deliveredMessages = $deliveryAgent->deliverData($members, $voiceMessageData, $voiceDataFormats->[0], %messageMetaInfo);
		
		foreach my $memBox (@{$members})
		{
			next unless ($memBox =~ m|^\d+$| && defined $self->{'boxes'}->{$memBox});
			$self->{'boxes'}->{$memBox}->refresh();
			
			
			if ($self->{'call_logfile'})
			{
				$self->{'_callLogger'}->newMessage( {
								'type'	=> $VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'},
								'boxnum'	=> $memBox,
								});
				$self->{'_callLogger'}->logMessage();
			}
			
			
		}
	
	} else {
		# Here we'd like to support delivery to 'list' boxes - which are like a mailing list
		# and end up in multiple boxes.
		my $type = $self->{'boxes'}->{$box}->type();
		
		VOCP::Util::log_msg("VOCP::record_message() - message recorded for $type box $box but type not supported yet.");
	} 
	
	umask $oldmask;
	
	VOCP::Util::log_msg("VOCP::record_message() delivered:" . Dumper($deliveredMessages))
		if ($main::Debug > 1);
		
	return $deliveredMessages;
	
}


sub getGroupMemberList {
	my $self = shift;
	my $box = shift;
	
	my @members;
	
	my $grmembers = $self->{'boxes'}->{$box}->getMembersArray();
	
	foreach my $amember (@{$grmembers})
	{
		# Avoid loops...
		next if ($self->{'_groupSearchSeen'}->{$amember});
		$self->{'_groupSearchSeen'}->{$amember} = 1;
		
		if ($amember =~ /^\d+$/)
		{
			# probably a box...
			next unless (defined $self->{'boxes'}->{$amember});
			my $memberType = $self->{'boxes'}->{$amember}->type() ;
			if ($memberType eq 'mail')
			{
				push @members, $amember;
			} elsif ($memberType eq 'group')
			{
				my $submembers = $self->getGroupMemberList($amember);
				push @members, @{$submembers};
			} else {
				VOCP::Util::error("getGroupMemberList() Box $amember of type $memberType is neither a mail nor group box");
			}
		} else {
			push @members, $amember;
		}
	}
	
	return \@members;
}	
			
			
			

=head2 play_box_message [BOXNUM [MSG]]

Plays the message for box BOXNUM (or current_box()), or MSG if 
defined. If MSG is not a full path to a file, the file is assumed
to be located relative to messagedir (set in genconfig file or with
new()).

If box BOXNUM has a restricted() password set, the user is asked
for the password, which is validated before the message is played.

If BOXNUM has auto_jump set, it will play the message then set the
current box to auto_jump and call play_box_message for that box.

=cut


sub play_box_message {
	my $self = shift;
	my $boxnum = shift; #optional, defaults to curent or root
	my $msg = shift; #optional, defaults to current box message
	
	
	my $box = $boxnum || $self->current_box() || $Default_box;
	
	$msg ||= $self->message($box);
	
	
	if ($self->{'always_multidigit_input'})
	{
		$self->inputMode($VOCP::Device::InputMode{'MULTIDIGIT'});
	} else {
		
		my $boxObject = $self->get_box_object($box) || return VOCP::Util::error("VOCP::play_box_message - invalid box '$box'");
		
		$self->inputMode($VOCP::Device::InputMode{'FIXEDDIGIT'}, $boxObject->numDigits());
		
	}
	
	
	# If the box has a 'restricted' password set, we ask for and validate
	# the password before playing the message
	my $restricted = $self->restricted($box);
	if (defined $restricted) {
		
		
		if (defined $self->{'messages'}->{'restricted'}) {
			my $rest_msg = VOCP::Util::full_path($self->{'messages'}->{'restricted'},
							$self->{'messagedir'});	
			$self->play($rest_msg);
		}
		
		unless ($self->ask_password() eq $restricted) {
			
			$self->play_error();
			VOCP::Util::error("Error accessing restricted box $box.  Exiting", $VOCP::Vars::Exit{'AUTH'});
			
		}
		
		VOCP::Util::log_msg("Access to restricted box $box, granted.");
		
	}
	
	unless ($msg) {
		VOCP::Util::log_msg("No message set for box $box.");
		return 1;
	
	}
	
	my $date = localtime(time);
	VOCP::Util::log_msg("$date: Access to box $box.");
	
	my $file = VOCP::Util::full_path($msg, $self->{'messagedir'});
	
	return $self->play($file);
	
	
}


=head2 play MSG

Plays MSG, which must be defined and contain the full path to 
the file to be played.

Returns true if no errors.

=cut

sub play {
	my $self = shift;
	my $msg = shift; #optional, defaults to current box message
		
	return $self->blockingPlay($msg);
	#return $self->{'voicedevice'}->play($msg);

}


sub blockingPlay {
	my $self = shift;
	my $msg = shift;
	
	return $self->{'voicedevice'}->play($msg);
	#return $self->{'voicedevice'}->play($msg);

}

=head2 play_num_messages NUM

Plays a number of files in sequence, to indicate to the user logged 
into message retrieval mode how many messages he has in his box.

The files played include 

	messages	youhave
	messages	messages

Set in the genconfig file.  Calls play_num() to say NUM.


=cut

sub play_num_messages {
	my $self = shift;
	my $number = shift;
		
	my $file = VOCP::Util::full_path($self->{'messages'}->{'youhave'},
					$self->{'messagedir'});
	$self->play($file);
	
	$self->play_num($number);
	
	$file = VOCP::Util::full_path($self->{'messages'}->{'messages'},
					$self->{'messagedir'});
	$self->play($file);
	

	return 1;

}

=head2 play_num NUM [REM_0]

Plays messages to user to 'read' NUM.

For numbers < 20, plays a single file which matches the number.
For 20 < numbers < 100, plays 2 files (e.g. 20 and 5 for 25).
For numbers > 99, says first digit, followed by other 2 as a pair
(i.e. 134 = "one" + "thirthy-four").
For numbers > 999, simply states each number in sequence.

The files played for each number are set in the genconfig file, as

messages	number	N	relative_path_to/number_file.rmd

where N is a numerical value.

If REM_0 is true, leading zeros will be removed (e.g. 006 = 6).

=cut


sub play_num {
	my $self = shift;
	my $number = shift;
	my $remove_zeros = shift; #optional
		
	unless ($number =~ /^\d+$/) {
		VOCP::Util::log_msg("Wanted to play number, got '$number'");
		
		return undef;
	}

	if ($remove_zeros) {
	
		#Remove useless 0's (e.g. 006 = 6)
		$number =~ s/^0+//
			unless ($number == 0);
	}
	
	my $length = length($number);
	
	my $file;
	
	
	# Act accordingly to size of number
	# be it 1, 2 or more digits long
	if ($length == 1) {  # Single number
	
		$file = VOCP::Util::full_path($self->{'messages'}->{'number'}->{$number},
					$self->{'messagedir'});
					
		$self->play($file);
		
		return 1;
		
	} elsif ($length == 2) { #Double digit number
		
		$number =~ /(\d)(\d)/;
		
		my $dec = $1;
		my $single = $2;
		
		if ( ($number > 9) && ($number < 20) ) { # 10-19 each have a particular file
			

			$file = VOCP::Util::full_path($self->{'messages'}->{'number'}->{$number},
					$self->{'messagedir'});

			$self->play($file);
			
			return 1;
			
		} else { # Number smaller than 10 (2 digit, eg 05) or greater than 19
		
			my $tens = $dec * 10;
			
			$file = VOCP::Util::full_path($self->{'messages'}->{'number'}->{$tens},
					$self->{'messagedir'});
					
			$self->play($file);
			
			return 1 if ($single == 0); #don't say 'twenty-zero'
			
			$file = VOCP::Util::full_path($self->{'messages'}->{'number'}->{$single},
					$self->{'messagedir'});
					
			$self->play($file);
		
			return 1;
		} # END number > 19
		
	} elsif ($length == 3) { # Say first number, then other two (as a pair)
		
		if ($number =~ /(\d)(\d\d)/) { # it should...
		
			# Menoum! Recursive call saves typing!
			$self->play_num($1);
			$self->play_num($2);
		} else {
			
			VOCP::Util::log_msg("Something strange in play_num(): $number doesn't have 3 digits?");
		}
		
		
	} else { # It is a quadruple digit number (or more)
	
		#Just say each number
		my @numbers = split ('', $number);
		
		foreach my $value (@numbers) {
			
			$file = VOCP::Util::full_path($self->{'messages'}->{'number'}->{$value},
					$self->{'messagedir'});
					
			$self->play($file);
		}
		
		
	} # END parse size of number
		
	return 1;
			
}


=head2 play_weekday DAY

Plays the file associated with a given DAY.  Note that DAY is a numerical
value, where Sunday = 0, Monday = 1... Saturday = 6.

=cut

sub play_weekday {
	my $self = shift;
	my $weekday = shift;
	
	unless (defined $weekday) {
		VOCP::Util::log_msg("Calling play_weekday() without passing a weekday");
		return undef;
	}
	
	unless (defined $Days{$weekday}) {
		VOCP::Util::log_msg("Calling play_weekday() with unknown weekday: $weekday");
		return undef;
	}
	
	return undef
		unless (defined $self->{'messages'}->{'day'}->{$Days{$weekday}});
	
	my $file = VOCP::Util::full_path($self->{'messages'}->{'day'}->{$Days{$weekday}},
					$self->{'messagedir'});
	
	$self->play($file);
	
	return 1;
}

=head2 play_error [MSG]

Plays MSG, if defined, or default error message (set in genconfig file).

Returns true value if message was played, false otherwise.

=cut

sub play_error {
	my $self = shift;
	my $msg = shift; #optional
	
	my $errormsg;
	
	if ($msg) { # Play 'custom' error msg
		
		$errormsg = VOCP::Util::full_path($msg, $self->{'messagedir'});
		
	} else { # Play default
	
		return undef
			unless (defined $self->{'messages'}->{'error'});
	
	 	$errormsg = VOCP::Util::full_path($self->{'messages'}->{'error'},
					$self->{'messagedir'}) ;
		
	}
	
	unless (-r $errormsg) {
		VOCP::Util::log_msg("Error msg ($errormsg) unreadable");
		return undef;
	}
	
	VOCP::Util::log_msg("Playing Error msg: $errormsg, while in box" . $self->current_box())
		if $main::Debug;

	$self->play($errormsg);
	
	return 1;
}

=head2 play_goodbye [MSG]

Plays MSG, if defined, or default goodbye message (set in genconfig file).

Returns true value if message was played, false otherwise.

=cut

sub play_goodbye {
	my $self = shift;
	my $msg = shift; #optional
	
	my $file;
	
	if ($msg) {
	
		$file = VOCP::Util::full_path($msg, $self->{'messagedir'});
	
	} elsif (defined  $self->{'messages'}->{'goodbye'}) {
		
		VOCP::Util::log_msg("Playing goodbye.")
			if ($main::Debug);
		$file = VOCP::Util::full_path($self->{'messages'}->{'goodbye'},
						  $self->{'messagedir'});
		
	}
	
	if ($file) {
		
		$self->play($file);
		
		return 1;
	}
	
	# Did not play
	return undef;
}


sub inputMode {
	my $self = shift;
	my $setTo = shift; # optionally set to mode
	
	return $self->{'voicedevice'}->inputMode($setTo);
}

=head1

####### Retrieving messages ########

	and command shells  

=head2 login

Checks whether a user login was successful.

Asks for BOXNUM and PASSWORD, if boxnumber is valid
and PASSWORD matches that for BOXNUM, then the current_box()
is set to BOXNUM and a true value is returned.

Else a false value is returned.

=cut

sub login {
	my $self = shift;
	
	VOCP::Util::log_msg("Logging into mailbox")
		if $main::Debug;
	
	$self->inputMode($VOCP::Device::InputMode{'MULTIDIGIT'});
	
	my $user = $self->ask_boxnumber();
	
	VOCP::Util::log_msg("Got user (boxnum): '$user'")
		if ($main::Debug > 1);
	
	my $passwd = $self->ask_password();
	
	VOCP::Util::log_msg("Got password: '$passwd'")
		if ($main::Debug > 1);
	
	# Invalid box - do this after password so it isn't used to check
	# for valid boxes by the evil phreakers
	return undef 
		unless ($self->valid_box($user));
	
	return undef unless ($self->password($user));
	
	# Invalid passwd
	return undef 
		unless ($self->check_password($user, $passwd));


	# Make sure current box is the user who logged in
	$self->current_box($user);
	
	my $boxObject = $self->get_box_object($user);
	
	unless ($boxObject && $boxObject->allowCNDlogin($self->{'call'}->{'caller_id'}))
	{
		VOCP::Util::log_msg("Caller from '$self->{'call'}->{'caller_id'}' attempted to login to restricted box $user");
			
		return undef; 
	}

	
	my $file;
	$file = VOCP::Util::full_path($self->{'messages'}->{'loggedin'},
				$self->{'messagedir'})
		if ($self->{'messages'}->{'loggedin'});
		
	
	$self->play($file)
		if ($file);

	VOCP::Util::log_msg("Login to box $user, successful.");
	
	# Success !	
	return 1;
	
}

=head2 ask_boxnumber [MSG]

Plays the message to request a BOXNUM (MSG if defined, else 
messages boxnum, set in genconfig file).

Returns the value entered by user.

=cut

sub ask_boxnumber {
	my $self = shift;
	my $msg = shift || $self->{'messages'}->{'boxnum'}; #optional
	
	VOCP::Util::log_msg("Asking user for boxnumber")
		if ($main::Debug);


	my $loginboxnumfile;
	
	# Get user (boxnumber)
	$loginboxnumfile = VOCP::Util::full_path($msg, $self->{'messagedir'})
		if ($msg);
	
		 
	
	$self->inputMode($VOCP::Device::InputMode{'MULTIDIGIT'});
	my $boxnum = $self->{'voicedevice'}->readnum($loginboxnumfile, $self->{'pause'}, $self->{'max_errors'});
	
	return $boxnum;
	
}

=head2 ask_password [MSG]

Plays the message to request a PASSWORD (MSG if defined, else 
messages password, set in genconfig file).

Returns the value entered by user.

=cut

sub ask_password {
	my $self = shift;
	my $msg = shift || $self->{'messages'}->{'password'}; #optional

	VOCP::Util::log_msg("Asking user for password")
		if ($main::Debug);
	
	my $loginpasswdfile;
	
	$loginpasswdfile = VOCP::Util::full_path($msg, $self->{'messagedir'})
				if ($msg);
	# Get password
	$self->inputMode($VOCP::Device::InputMode{'MULTIDIGIT'});
	my $passwd = $self->{'voicedevice'}->readnum($loginpasswdfile, $self->{'pause'}, $self->{'max_errors'});

	VOCP::Util::log_msg("User answered: $passwd")
		if ($main::Debug > 1);
		
	return $passwd;
}

=head2 retrieve_messages [BOXNUM]

Lands the user in message retrieval mode, for box BOXNUM (or
current_box(), if not set). Be sure to call login() before allowing
a user into message retrieval mode.

Calls play_num_messages() to indicate the number of messages
in BOXNUM, returns immediately if 0 messages.

The user may now enter retrieval mode commands, which are 
DTMF sequences whose first digit is an action code and subsequent
digits are parameters.

When in message retrieval mode, the user may select the following 
options: play, delete, date, help, quit or return to root box.  Each 
action has an associated number, by default:

	1	play
	3	delete
	5	date
	9	help
	0	quit

For play, delete and date, the keys following the action number indicate which 
message to apply the action to.  For example, '115' will play ('1') message 
15, and 309 will delete ('3') message 09.  The special sequence '00' after an
action code indicates that the command should be applied to ALL 
messages, thus '300' deletes all the messages in the box. The correspondance
between keys and actions is set in the genconfig file, with lines of
the form:

menu	N	ACTION


For each action, the method call a subroutine with a name of the form
'messages_ACTION' where action is one of play, delete, date...

The system loops in message retrieval mode until the user selects 
quit ('0', by default) or enters the root box number ('001') to return
to the starting menu.

=cut

sub retrieve_messages {
	my $self = shift;
	my $boxnum = shift; #optional
	
	$boxnum ||= $self->current_box();
	
	
	if ($self->{'messages'}->{'help'}) {
			
		my $help = VOCP::Util::full_path($self->{'messages'}->{'help'},
						$self->{'messagedir'});
		$self->play($help);
	}
	
	my $boxObject = $self->get_box_object($boxnum);
	
	my $messages = $self->list_messages($boxnum);
	
	my $nummsg = scalar @{$messages};
	
	$self->play_num_messages($nummsg);
	
	my $enter_cmd;
	if ($self->{'messages'}->{'enter_command'}) {
			
		$enter_cmd = VOCP::Util::full_path($self->{'messages'}->{'enter_command'},
						$self->{'messagedir'});
	}
	
	my $first_digit;
	my $errors = 0;
	my $maxerrors = $self->{'max_errors'} || 3;
	my $continue = 1;
	while ($continue) {
	
		# exit if we're over max errors
		if ($errors >= $maxerrors) {
			VOCP::Util::log_msg("Too many errors in retrieve msg mode (box $boxnum)");
			$self->play_goodbye();
			$self->{'voicedevice'}->disconnect();
			VOCP::Util::error("Exit from retrieve message mode");
		}
	
	
		# Tell user to enter something
		
		my $choice = $self->{'voicedevice'}->readnum($enter_cmd, $self->{'pause'} * 3, $self->{'max_errors'});
		
		# Return to root box if that is user choice
		if ($choice eq $Default_box) {
			VOCP::Util::log_msg("User selected to return to the root box ($Default_box)");
			$self->current_box($Default_box);
			return 1;
		}
	
		if ($choice =~ /^(\d)/) { #Most choices will...
			
			# First digit indicates category of selection
			# other digits are dealt with in subs
			$first_digit = $1;
		
			my $sub = "messages_" . $self->{'menu'}->{$first_digit};
			
			unless (defined $self->{'menu'}->{$first_digit} 
				 		&& $self->can($sub) ) {
				$self->play_error();
				$errors++;
				next;
			}
			
			$continue = $self->$sub($messages, $choice, $boxObject);
			
			# If messages have been deleted, retrieve the list which has
			# changed.
			$messages = $self->list_messages($boxnum)
				if ($self->{'menu'}->{$first_digit} eq 'delete');
			
		} else {
		
			$self->play_error();
			$errors++;
		}
		
	}
	
	# The user chose to quit
	if ($self->{'menu'}->{$first_digit} eq 'quit') {
	
		VOCP::Util::log_msg("User has selected to quit while retrieving messages")
			if ($main::Debug);
		
	} else { # Don't know how we got here... we quit

		VOCP::Util::log_msg("A msg retr sub (other than quit) has returned 0... quitting");
	}
	
	return 0;
	
	
}

# 00 = all
# XX = play msg XX
sub messages_play {
	my $self = shift;
	my $messages = shift;
	my $choice = shift;
	my $boxObject = shift;
	
	$choice =~ /^(\d)(\d+)/;
	my $first_digit = $1;
	my $option = $2;
	
	
	
	if ($option == 0) { #play all
	
		VOCP::Util::log_msg('Playing all messages')
			if $main::Debug;
		
		my $num;
		foreach my $msg (@{$messages}) {
			
			$num++;

			$self->play_num($num);
			
			my $file = VOCP::Util::full_path($msg, $self->{'inboxdir'}); 
		
			$self->play($file);
			
		}
	
	} else {
	
		my $msgnum = $option - 1; # An array!
		
		VOCP::Util::log_msg("Playing message $option")
			if $main::Debug;
		
		unless ($messages->[$msgnum]) {
			$self->play_error();
			return 1;
		}
		
		my $file = VOCP::Util::full_path($messages->[$msgnum], $self->{'inboxdir'});
		
		$self->play($file);
	}
	
	
	return 1;
}

	
# 00 = all
# XX = rm msg XX
sub messages_delete {
	my $self = shift;
	my $messages = shift;
	my $choice = shift;
	my $boxObject = shift;
	
	
	$choice =~ /^(\d)(\d+)/;
	my $first_digit = $1;
	my $option = $2;
	
	
	if ($option == 0) { #delete all
	
		VOCP::Util::log_msg('Deleting all messages')
			if $main::Debug;
		
		$boxObject->deleteAllMessages();
		

	} else { #delete only one
	
		VOCP::Util::log_msg("Deleting message $option")
			if $main::Debug;
		
		my $msgnum = $option - 1; # An array!
		
		unless ($messages->[$msgnum]) {
			$self->play_error();
			return 1;
		}
		my $boxnum = $boxObject->number();
		my $messageFile = $messages->[$msgnum];
		my ($file, $ext) = VOCP::Util::clean_filename($messageFile);
	
		unless ($file =~ m|^$boxnum-(\d+)|)
		{
			VOCP::Util::log_msg("VOCP::messages_delete() Strange filename found '$file' skipping");
			return 1;
		}
		
		my $msgId = $1;
		
		my $msgObject = $boxObject->fetchMessageByID($msgId);
		
		unless ($msgObject)
		{
			VOCP::Util::log_msg("VOCP::messages_delete() Could not find message with id '$msgId' - skipping delete.");
			return 1;
		}
		
		$boxObject->deleteMessageByID($msgId);
		
	}
	
	return 1;
	
}	


sub messages_date {
	my $self = shift;
	my $messages = shift;
	my $choice = shift;
	my $boxObject = shift;
	

	$choice =~ /^(\d)(\d+)/;
	my $first_digit = $1;
	my $option = $2;
	
	# Make sure the message exists
	# 00 (all) is an invalid selection - do them one at a time.
	my $msgnum = $option - 1; #an array...
	unless($messages->[$msgnum] && ($msgnum >= 0)) {
		$self->play_error();
		return 1;
	}
	
	my $file = VOCP::Util::full_path($messages->[$msgnum], $self->{'inboxdir'});

	# Stat gives us:
	#($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
	# $atime,$mtime,$ctime,$blksize,$blocks)
	my @stat = stat($file);
	
	my $mtime = $stat[9]; #mod time
	
	unless ($mtime) {
		$self->play_error();
		return 1;
	}
	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime($mtime);
						
	# Play the info, day/hour/min
	$self->play_weekday($wday);
	$self->play_num($hour);
	$self->play_num($min);
	
	return 1;
	
}

# Plays this boxe's message for user
sub messages_listen_box_message {
	my $self = shift;
	my $messages = shift;
	my $choice = shift;
	
	my $box_msg = $self->message();
	
	unless ($box_msg) {
		VOCP::Util::log_msg("Trying to listen to message for "
				. $self->current_box() . " when none is set.");
				
		$self->play_error();
		
		#Back to msg retrieval mode
		return 1;
	}
	
	my $file = VOCP::Util::full_path($box_msg, $self->{'messagedir'});
	
	$self->play($file);
	
	return 1;
}


sub messages_record_box_message {
	my $self = shift;
	my $messages = shift;
	my $choice = shift;
	
	my $box_msg = $self->message();
	
	unless ($box_msg) {
		VOCP::Util::log_msg("Trying to record a message for "
				. $self->current_box() . " when none is set.");
				
		$self->play_error();
		
		#Back to msg retrieval mode
		return 1;
	}
	
	# Make sure the user wishes to proceed.
	# my $choice = 1;
	if ($self->{'messages'}->{'record_box_verif'}) {
		my $verify = VOCP::Util::full_path($self->{'messages'}->{'record_box_verif'},
						$self->{'messagedir'});
		
		
		$choice = $self->{'voicedevice'}->readnum($verify, $self->{'pause'}, $self->{'max_errors'});
		
	}
	
	if ($choice eq '2') { # Does NOT wish to proceed
	
		#Back to msg retrieval mode
		return 1;
	} elsif ($choice ne '1') { # Some invalid choice
	
		$self->play_error();
		
		#Back to msg retrieval mode
		return 1;
	}
	
	# User has chosen to proceed
	my $file = VOCP::Util::full_path($box_msg, $self->{'messagedir'}, 'SAFE');

	# We're being super safe...  don't want to record over /etc/passwd now...
	# Check that the path starts with the right stuff.	
	VOCP::Util::error("Trying to record but this file is not within the messagedir: $file")
		unless ($file =~ m|^$self->{'messagedir'}|);
	
	$self->Beep();
	
	$self->Record($file);
	
	return 1;
	
}

					
sub messages_help {	
	my $self = shift;
	my $messages = shift;
	my $choice = shift;

	VOCP::Util::log_msg("Playing retrieve messages help")
		if ($main::Debug);
	
	#Play help 
	foreach my $number (sort keys %{$self->{'menu'}}) {
		
		my $action = $self->{'menu'}->{$number};
		
		my $msg = $self->{'messages'}->{'menu'}->{$action};
		
		if (defined $msg) {
			
			VOCP::Util::log_msg("Playing help for number $number")
				if ($main::Debug > 1);
			
			my $file = VOCP::Util::full_path($msg, $self->{'messagedir'});
			
			$self->play_num($number);
			
			$self->play($file);
		}
	}
	
	return 1;
	
}
		
sub messages_quit {
	my $self = shift;
	my $messages = shift;
	my $choice = shift;
	
	return 0;
	
}

=head2 list_messages [BOXNUM [LONG [SORTBY [FORCEREFRESH]]]]

Returns an array reference of all messages in inboxdir (set in genconfig
or with new()) that match the name 'BOXNUM-XXXX.rmd'.

If LONG is true, the returned array contains a listing for each
message that contains all the info of an 'ls' with the long option.

=cut

sub list_messages {
	my $self = shift;
	my $box = shift;
	my $long = shift || 'SHORT'; #optional
	my $sortby = shift || 'DATE';
	my $refresh = shift; # optionally force a box refresh
	
	$box ||= $self->current_box();
	
	VOCP::Util::log_msg("Getting list of messages for box $box")
		if ($main::Debug);
	
	VOCP::Util::error("VOCP::list_messages() called without specifying a box number.") unless (defined $box);
		
	my @files = ();
		
	VOCP::Util::error("VOCP::list_messages() called for non-existant box $box")
		unless (defined $self->{'boxes'}->{$box});

	my $messages = $self->{'boxes'}->{$box}->listMessages($sortby, $refresh);
	if ($long eq 'SHORT' || $long eq 'short')
	{
		foreach my $msg (@{$messages})
		{
			$files[scalar @files] = VOCP::Util::full_path($msg->filename(), $self->{'inboxdir'});
		}
	} elsif ($long eq 'LONG' || $long eq 'long') {
		
		foreach my $msg (@{$messages})
		{
			#mode||nlink||uid||gid||size||mtime||afilename||flags
			my $dt = $msg->getDetails();
			my @details = ($dt->{'mode'},$dt->{'nlink'}, $dt->{'uid'}, $dt->{'gid'}, $dt->{'size'}, 
						$dt->{'time'}, $dt->{'filename'}, $dt->{'flags'});
			$files[scalar @files] = join('||',  @details);
		}
	} elsif ($long eq 'OBJECT' || $long eq 'object')
	{
		foreach my $msg (@{$messages})
		{
			$files[scalar @files] = $msg;
		}
	} else {
		VOCP::Util::error("VOCP::list_messages() called with invalid parameter '$long'");
	}
	
	return \@files;
	
	
}


sub list_boxes {
	my $self = shift;
	my $type = shift; #optionally retrieve only boxes of type TYPE
	
}
	
	


##### Command shell ######


=head2 run_script_box [BOXNUM]

=cut
sub run_script_box {
	my $self = shift;
	my $boxnum = shift; #optional
	
	$boxnum ||= $self->current_box();
	
	# Verify that this is a script box
	my $boxType = $self->type($boxnum);
	if ($boxType ne 'script')
	{
		VOCP::Util::error("VOCP::run_script_box called for box '$boxnum' which is NOT a script box ($boxType)");
	}
	
	
	VOCP::Util::log_msg("User access to script box $boxnum")
		if ($main::Debug);
	
	my $scriptBox = $self->get_box_object($boxnum) || VOCP::Util::error("VOCP::run_script_box could not fetch box object $boxnum");
	my $script = $scriptBox->script() ||  VOCP::Util::error("VOCP::run_script_box no script set for box $boxnum");
	$script = VOCP::Util::full_path($script, $self->{'commanddir'}, 'SAFE');
	
	my $max_errors = $self->{'max_errors'} || 3;
	
	my $owner = $scriptBox->owner();
	
	#if we are root and need to swap uid, so we do
	#so until the end of the prog.
	my $wasroot;
	$wasroot++
		if ($> == 0);
	
	if ( $wasroot && ($owner ne 'root') ) { 
		my ($name,$passwd,$uid,$gid,$quota,$comment,
			$gcos,$dir,$shell,$expire) = 
			getpwnam($owner);
		
		VOCP::Util::error("In command shell for box $boxnum - can't suid to "
				. "invalid system user (owner) $owner")
			unless(defined $uid);

		$> = $uid;
	}
	
	
	my $input_type = $scriptBox->input();
	my $input;
	if ($input_type && ($input_type ne 'none'))
	{
		$self->inputMode($VOCP::Device::InputMode{'MULTIDIGIT'});
		# Set the sub that handles type of input (raw or text)
		my $sub = "get_command_input_$input_type";
			VOCP::Util::error("Input type $input_type (in box $boxnum) leads to undefined "
					. "handler $sub()")
				unless ($self->can($sub));
			
		# Get user input (and optionally translate to text)
		$input = $self->$sub();
		
		$input =~ s/[^\d\w\*]+//g;
		unless ((! $input) || $input =~ m|^([\d\w\*]+)$|)
		{
			VOCP::Util::error("Strange input recieved: $input");
		}
		$input = $1; # untaint
	}
	
	$script =~ s/[\*]+/ /g;
	
	$script .= " \"$input\"" if (defined $input);
	
	$script =~ s/[;\\`|#!]+/ /g;
	
	my $return_type = $scriptBox->return() || 'exit';
	my @cmdOutput;
	if ($return_type eq 'exit')
	{
		my $ret = system("$script");
		push @cmdOutput, $ret;
	} else {
		my $scriptfh = VOCP::PipeHandle->new();
		$scriptfh->open("$script |")
			|| VOCP::Util::error("Could not open script ('$script') for box $boxnum");
		
		while (my $line = $scriptfh->getline())
		{
			push @cmdOutput, $line;
		}

		$scriptfh->close();
	}
	
	
	$> = 0 if ($wasroot);
	
	$self->play_command_return($return_type, \@cmdOutput);
	
	return;
}

=head2 command_shell [BOXNUM]

Lands the user in the command shell set up for box BOXNUM (or
current_box(), if not set). Be sure to call login() before allowing
a user into a command shell.

When in the command shell, the user enters DTMF sequences that are
set to execute programs on the host machine.

The user exits the command shell by entering '0'.

The commands available in box BOXNUM are setup in the boxconfig
file, and are of the form:

command BOXNUM selection return run

See the documentation or the boxconfig file itself for more info.

Depending on the return type set for the commands, either the exit
code, the (numerical) output of the command or the contents of the output
file name will be played to the 
user.

Note:  For security, all command shells must be password protected.  
The programs are executed with the priviledges associated with the 
box owner (the programs run suid to the box owner).  
Also, the program sets for the command shells must all be contained 
under the commanddir directory (set in the configuration file or with 
new()).  You may use symlinks in the commanddir directory to the 
programs you wish to be able to execute in the shells.

=cut

sub command_shell {
	my $self = shift;
	my $boxnum = shift; #optional
	
	$boxnum ||= $self->current_box();
	
	VOCP::Util::log_msg("Logged into command shell $boxnum");
	
	my $max_errors = $self->{'max_errors'} || 3;
	
	my $owner = $self->owner($boxnum);
	
	#if we are root and need to swap uid, so we do
	#so until the end of the prog.
	my $wasroot;
	$wasroot++
		if ($> == 0);
	
	if ( $wasroot && ($owner ne 'root') ) { 
		my ($name,$passwd,$uid,$gid,$quota,$comment,
			$gcos,$dir,$shell,$expire) = 
			getpwnam($owner);
		
		VOCP::Util::error("In command shell for box $boxnum - can't suid to "
				. "invalid system user (owner) $owner")
			unless(defined $uid);

		$> = $uid;
	}
	
	unless ($self->{'disable_cmdshell_list'})
	{
		VOCP::Util::log_msg("disable_cmdshell_list is off - playing 'help' message.");
		
		if ($self->{'messages'}->{'help'}) {
			
			my $help = VOCP::Util::full_path($self->{'messages'}->{'help'},
						$self->{'messagedir'});
			$self->play($help);
		}
	}
	my $enter_cmd;
	if ($self->{'messages'}->{'enter_command'}) {
			
		$enter_cmd = VOCP::Util::full_path($self->{'messages'}->{'enter_command'},
						$self->{'messagedir'});
	}
	my $continue = 1;
	my $errors = 0;
	$self->inputMode($VOCP::Device::InputMode{'MULTIDIGIT'});
	while ($continue) {
	
		
		#$self->play($enter_cmd) if ($enter_cmd); Will uncomment when we have 2 different messages for
		# enter_command and enter_command_input
		
		my $choice =  $self->{'voicedevice'}->readnum(undef, $self->{'pause'} * 3, 1); # No message, 1 repeat
	
		$choice = '' unless (defined $choice);
	
		VOCP::Util::log_msg("Got choice $choice, in command shell")
			if ($main::Debug);
	
	
		if ($errors >= $max_errors) {
			VOCP::Util::log_msg("Too many errors in command shell box $boxnum");
			$self->play_goodbye();
			$self->{'voicedevice'}->disconnect();
			VOCP::Util::error("Exit from command shell");
		}
		
		# Check if selected exit
		if ($choice eq $Default_box) {
			VOCP::Util::log_msg("User selected to return to root box (cmd shell) in $boxnum")
				if ($main::Debug);
				
			# swap back to root
			$> = 0 if ($wasroot);
			# Set the current box
			$self->current_box($Default_box);
			return 1;
		
		} elsif ($choice eq '0') {
			VOCP::Util::log_msg("User selected to exit (cmd shell) from $boxnum")
				if ($main::Debug);
			$> = 0 if ($wasroot);
	
			return 0;
				
		} elsif ($choice eq '') 
		{
			# No choice entered - timeout and count as an error
			$errors++;
			$self->play_error();
			
			next;
		}
		
		# Get the command to execute	
		my $cmd;
		my $cmdshell_list_request = defined $self->{'cmdshell_list_key'} ? $self->{'cmdshell_list_key'} : '9';
		 
		my $return_type;
		
		if ($choice eq $cmdshell_list_request && ! $self->{'disable_cmdshell_list'}) {
		
			VOCP::Util::log_msg("User selected to command listing while in cmd shell $boxnum")
				if ($main::Debug);
			
			$cmd = $self->{'programs'}->{'cmdshell_list'} . ' ' . $boxnum;
			$return_type = 'tts';
			
		} else {
			$cmd = $self->command($boxnum, $choice);
			$return_type = $self->command_return($boxnum, $choice) || 'exit';
		
		}
		
		# Make sure we have a command specified and that its path is relative
		unless (defined $cmd && $cmd !~ m|^\s*/|) {
		
			VOCP::Util::log_msg("No selection set for '$choice' in box $boxnum or path not relative."); 
		
			$errors++;
			$self->play_error();
		
			$choice =~ s/[^\d]+//g;
			$self->play_num($choice) if ($choice =~ m/\d/);
		
			next;
		}
		
		# Make sure the command to execute is below the specified command dir and is 'SAFE' (no tricky ../../ or weirdness)
		my $cmdDir = $self->{'commanddir'} || '/var/spool/voice/commands';
		$cmd = VOCP::Util::full_path($cmd, $cmdDir, 'SAFE');
	
		#Get user input for command, if set
		my ($input, $input_type);
		$input_type = $self->command_input($boxnum, $choice);
		
		if ($input_type && $input_type ne 'none') { #If we need input
		
			# Set the sub that handles type of input (raw or text)
			my $sub = "get_command_input_$input_type";
			VOCP::Util::error("Input type $input_type (in box $boxnum) leads to undefined "
					. "handler $sub()")
				unless ($self->can($sub));
			
			# Get user input (and optionally translate to text)
			$input = $self->$sub();
			$input =~ s/[^\d\w\*]+//g;
			unless ((! $input) || $input =~ m|^([\d\w\*]+)$|)
			{
				VOCP::Util::error("Strange input recieved: $input");
			}
			
			$input = $1; # untaint
			
		}

		$cmd =~ s/[\*]+/ /g;
	
		$cmd .= " \"$input\"" if (defined $input);
	
		$cmd =~ s/[;\\`|#!]+/ /g;
	
		
		my @output;
		if ($return_type eq 'exit')
		{
			my $ret = system("$cmd");
			push @output, $ret;
		} else {
		
			my $scriptfh = VOCP::PipeHandle->new();
			$scriptfh->open("$cmd |")
				|| VOCP::Util::error("Could not open script ('$cmd') for box $boxnum");
		
			while (my $line = $scriptfh->getline())
			{
				push @output, $line;
			}

			$scriptfh->close();
			
			
		}
	
		$self->play_command_return($return_type, \@output);
		
	} # end while continue
	
	# Reset our uid to root, if it was at beginning
	$> = 0 if ($wasroot);
	
	return 1;
	
	
}




=head2 play_command_return TYPE OUTPUTAREF

Used by the command shell and script boxes, play_command_return() deals with playing appropriate files to
the user, depending on the TYPE ('exit', 'output', 'file', 'tts') and the content of the OUTPUTAREF array ref.

=cut
	
sub play_command_return {
	my $self = shift;
	my $type = shift;
	my $outputArray = shift;
	
	VOCP::Util::log_msg("VOCP::play_command_return() About to output ($type) result of command: " . join(",",@{$outputArray} ))
					if ($main::Debug > 1);
	
	if ($type eq 'file')
	{
	
		# Play each file output by script in turn
		foreach my $outfile (@{$outputArray})
		{
			chomp($outfile);
			
			VOCP::Util::log_msg("command result: play file '$outfile'")
				if ($main::Debug > 1);

			unless (-r $outfile)
			{
				VOCP::Util::log_msg("cannot read '$outfile'. Skipping.");
				next;
			}

			if ($outfile =~ /\.rmd$/i)
			{
				VOCP::Util::log_msg("Playing $outfile.")
						if ($main::Debug > 1);

				$self->play($outfile); #play the file

			} elsif ($outfile =~ /\.(\w{2,4})$/)
			{
				my $type = $1;
				$self->_convert_and_play($outfile, $type);
				
			} else
			{
				VOCP::Util::log_msg("Unknown file type returned by command shell: '$outfile'. Ignoring.");
				next;
			}
		}
	} elsif ($type eq 'tts')
	{
	
		# Convert text to sound in correct format.
		# This is tricky because there are a lot of temp files involved:
		# data -> txt, txt -> pvf, pvf -> rmd.
		# Watch closely - there are still some risks but they are minimized by the use
		# of the util package's safeTempFile routine in conjunction with the 'nooverwrite' flags
		
		
		# Start by getting content and cleaning it up
		my $content = join(' ', @{$outputArray});
		
		$content =~ s/[^\S]{15,}/ /smg; # Unbroken strings that are too long
		$content =~ s/(.)\1{6,}/$1/smg; # Remove excessive repeats ('xxxxxxxxxxxxxxxxxxx' becomes 'x')
		$content =~ s/[^\s\w\d\@\.,\!#'<>\/-]+/ /g; # Get rid of all 'unknown quantities'.
		$content =~ s/\s\s+/ /smg; # Get rid of large numbers of consecutive spaces
	
		$content = 'No content was output by command shell selection.' unless ($content =~ /[\w\d]+/);
		
		
		my $tmpDir = $self->{'tempdir'} || '/tmp' ;
		my $baseTempName = "$tmpDir/vocpscript$$";
		
		# Write the text to a temp file
		my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseTempName);
		
		return VOCP::Util::error("VOCP::play_command_return(): Problem creating a tempfile based on '$baseTempName'")
			unless ($tmpFileHandle && $tmpFileName) ;
		
		$tmpFileHandle->autoflush();
		
		$tmpFileHandle->print($content);
		
		
		# Create a safe name for the output pvf file
		my ($pvfFh, $pvfFileName) = VOCP::Util::safeTempFile($baseTempName);
		unless ($pvfFh && $pvfFileName)  {
			unlink $tmpFileName;
			$tmpFileHandle->close();
			
			return VOCP::Util::error("VOCP::play_command_return(): Problem creating a tempfile based on '$baseTempName'");
		}
		
		# Unlink and use 'nooverwrite' flag
		unlink $pvfFileName;
		$pvfFh->close();
		
		
		VOCP::Util::log_msg("VOCP::play_command_return Calling X2pvf($tmpFileName, $pvfFileName, 'txt', 'NOOVERWRITE')")
			if ($main::Debug > 1);
		
		my ($error, $message) = $self->X2pvf($tmpFileName, $pvfFileName, 'txt', 'NOOVERWRITE');
		
		# done, get rid of the temp txt file.
		
		unlink $tmpFileName unless ($main::Debug > 2);
		$tmpFileHandle->close();
		if ($error)
		{
			return VOCP::Util::error("VOCP::play_command_return(): Encountered an error converting to PVF: $message");
		}
		# No error, we can assume the pvf file was created.
		
		# Get a safe file name for rmd file.
		my ($outputFileHandle, $outputFileName) = VOCP::Util::safeTempFile($baseTempName);
		
		# Unlink and call pvf2x with nooverwrite flag
		unlink $outputFileName;
		$outputFileHandle->close();
		
		VOCP::Util::log_msg("VOCP::play_command_return Calling pvf2X($pvfFileName, $outputFileName, 'rmd', undef, 'NOOVERWRITE')")
			if ($main::Debug > 1);
		
		($error, $message) = $self->pvf2X($pvfFileName, $outputFileName, 'rmd', undef, 'NOOVERWRITE');
		unlink $pvfFileName unless ($main::Debug > 2);
		if ($error)
		{
			return VOCP::Util::error("VOCP::play_command_return(): Error converting pvf to rmd - $message");
		}
		
		# Horray, we made it.
		
		$self->play($outputFileName);
		
		unlink $outputFileName unless ($main::Debug > 2);

	} elsif ($type eq 'exit' || $type eq 'output')
	{
		
		# Get the line seperator, if more than one line in output
		my $linefile = VOCP::Util::full_path($self->{'messages'}->{'line'},
						$self->{'messagedir'})
				if ($self->{'messages'}->{'line'} && (scalar @{$outputArray} > 1) );
		
		#Say the numbers if at least one digit
		my $firstdone = 0;
		foreach my $line (@{$outputArray}) {
			
			chomp($line); # get rid of \n's

			VOCP::Util::log_msg("Reading command result '$line'")
				if ($main::Debug > 1);
			
			if ($line =~ /\d/) { #At least one digit
				$line =~ s/\D+//g; #Get rid of non digits
				
				$self->play($linefile)
					if ($linefile && $firstdone);
				
				$firstdone++;
				
				$self->play_num($line);
			}
		} # end foreach line
	} elsif ($type eq 'sendfax') {
	
		my $file = $outputArray->[0];
		
		chomp($file);
		
		VOCP::Util::error("VOCP::play_command_return(): box return type is 'sendfax' but no filename specified")
			unless ($file);
			
		
		VOCP::Util::error("VOCP::play_command_return():	box trying to sendfax but '$file' cannot be found or is unreadable")
			unless(-e $file && -r $file);
		
		
		$self->{'voicedevice'}->sendImage($file);
	
	} else {
		
		VOCP::Util::error("VOCP::play_command_return(): Bad output type ($type) passed.");
	}
	
	return 1;
}



# _convert_and_play FILE TYPE
# internal sub used by command_shell() to convert files output by commands
# to rmd format and play the resulting sound file.
sub _convert_and_play {
	my $self = shift;
	my $infile = shift;
	my $type = shift;

	my ($playfile, $tempfile, $ret, $err);
	my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 );

	VOCP::Util::log_msg("_convert_and_play: Converting $infile ($type) to rmd")
		if ($main::Debug > 1);

	while ( ! ($tempfile || -r $tempfile ))
	{
		$tempfile = $self->{'tempdir'} . "/" . join ("", @chars[ map { rand @chars } (1 .. 9) ]) . '.pvf';
	}

	($ret, $err) = $self->X2pvf($infile, $tempfile, $type);
	if ($ret)
	{
		VOCP::Util::log_msg($err);
		next;
	}
	
	while (! ($playfile || -r $playfile ))
	{
		$playfile = $self->{'tempdir'} . "/" . join ("", @chars[ map { rand @chars } (1 .. 9) ]) . '.rmd';
	}

	($ret, $err) = $self->pvf2X($tempfile, $playfile, 'rmd', $self->{'rmdformat'} . " " . $self->{'rmdcompression'});
	if ($ret)
	{
		VOCP::Util::log_msg($err);
		next;
	}
	$self->play($playfile); #play the file
	unlink $tempfile, $playfile;

	return;
}





=head1 

	##### Getting keypresses #####




=head2 get_selection [SELEC]

Gets and returns a user\'s selection.  If SELEC is passed,
it treated as input to make a selection, else DTMF input is retrieved
with a call to the device's readnum().

The input is the validated (call to valid_box()).  If the input
was valid (could be a box number, a branch, a request for a command shell
or a request to retrieve messages), the valid_box() value is returned.

If the input is invalid, the user gets another chance to enter dtmf input,
until the number of invalid selections is greater that max_errors (set in
genconfig or with call to new()).  At that time, the user is disconnected
from the system and the program exits.

=cut

sub get_selection {
	my $self = shift;
	my $selec = shift;
	my $pause = shift;
	my $numDigits = shift; # optionally get a fixed number of digits
	
	$selec =  '' unless (defined $selec); #optional
	$pause =  $self->{'pause'} unless (defined $pause); #set a default pause if not passed as argument
	
	
	VOCP::Util::log_msg("Getting user selection...")
		if ($main::Debug);
	
	# check if we've got any initial input,
	my $input = $selec;
	
	my $autojump = $self->auto_jump();
	my $boxnum;
	my $inputMode = $self->inputMode();
	if ($input =~ /[\d#\*a-d]+/i 
		&& ($inputMode != $VOCP::Device::InputMode{'MULTIDIGIT'}) )
	{
		# already have input
		VOCP::Util::log_msg("We already have some input ($input) and mode is $inputMode.")
			if ($main::Debug > 1);
		
		if ($self->valid_box($input))
		{
			# just return the valid box associated with the input
			
			VOCP::Util::log_msg("Got pre-selection: $input")
				if ($main::Debug);
				
			return $self->valid_box($input);
		} elsif ($autojump && $self->{'autojump_preselect'})
		{
			# the input is invalid, but it may be valid in the autojumped box...
			my $branch = $self->get_branch($input, $autojump);
			if ($branch)
			{
				$boxnum = $self->valid_box($branch);
				
				if ($boxnum)
				{
				
					VOCP::Util::log_msg("Input '$input' is valid in $autojump box - returning box '$boxnum'")
						if ($main::Debug);
				
					return $boxnum ;
				}
			}
		} # end if the input was valid
		
	} # end if we were passed some input
	
	
	
	# We get here when no initial selection was passed and there's no 
	# autojump magic going on.
	my $maxerrors = $self->{'max_errors'} || '5';
	my $numerrors = 0;
	
	# While we haven't found a box matching user input, get more 
	# input and try it until we find a box or hit the max errors.
	while ( (! $boxnum) && ($numerrors <= $maxerrors) ) {
	
		# get some input
		VOCP::Util::log_msg("VOCP::get_selection() Calling readnum()") 
			if ($main::Debug > 1);
		
		$input .= $self->{'voicedevice'}->readnum(undef, $self->{'pause'}, 0, $numDigits);
		
		VOCP::Util::log_msg("VOCP::get_selection() currently has input '$input'") 
			if ($main::Debug > 1);
		
		# check if it's valid
		$boxnum = $self->valid_box($input);
		if ($boxnum)
		{
			# got a box!
			VOCP::Util::log_msg("Caller entered '$input' which leads to '$boxnum'")
				if ($main::Debug);
		} elsif ($autojump) {
		
			# no input or bad input, jump the jump
			return $autojump;
			
			
		} else {
		
			# got bad input
			VOCP::Util::log_msg("Invalid selection ($input)")
				if ($main::Debug);
		
			$self->play_error();
			if ($main::Debug)
			{
				my $badnum = $input;
				$badnum =~ s/[^\d]+//g;
				$self->play_num($badnum) if ($badnum =~ /\d/);
			}
		
			if ($self->{'repeat_message_on_error'})
			{
				my $message = $self->message();
			
				if ($message)
				{
					$message = VOCP::Util::full_path($message, $self->{'messagedir'});
					$self->play($message) ;
				}
			
			}
			
			$numerrors++;
			$input = '';
			# Try again
		}
		
		
	}
	
	if ( $numerrors >= $maxerrors) {
	
		$self->play_goodbye();
		
		
		VOCP::Util::log_msg("$numerrors errors for user in box " 
				. $self->current_box() . ". Disconnecting");
		
		$self->shutdown($VOCP::Vars::Exit{'MAXERRORS'});
		
	}

	return $boxnum;
}

sub get_command_input_raw {
	my $self = shift;
	my $timeout = shift || '10'; #optional (approx) time to wait for input
	
	VOCP::Util::log_msg('Getting raw input for command')
		if ($main::Debug);
	
	# Play the request for input
	
	my $entercmdfile;
	
	$entercmdfile = VOCP::Util::full_path($self->{'messages'}->{'enter_cmd_input'},
						$self->{'messagedir'})
				if (defined $self->{'messages'}->{'enter_cmd_input'});
	
	my $input = $self->{'voicedevice'}->readnum($entercmdfile, $timeout, $self->{'max_errors'});
	
	
	VOCP::Util::log_msg("Got $input for command")
		if ($main::Debug);
	
	return $input;
	
}

sub get_command_input_text {
	my $self = shift;
	my $timeout = shift || '15'; #optional (approx) time to wait for input
	
	VOCP::Util::log_msg('Getting text input for command')
		if ($main::Debug);
	
	my ($raw, $done);
	do {
		$raw = $self->get_command_input_raw($timeout);
		
		if (length($raw)%2 == 0) { #Must be a multiple of 2 to be valid
			
			$done++;
			
		} else { #Invalid
			
			VOCP::Util::log_msg("Got invalid input, $raw (not a multiple of 2)")
				if ($main::Debug);
				
			$self->play_error();
		}
		
	} until($done);
	
	my $text = VOCP::Util::dtmf_to_text($raw);
	
	VOCP::Util::log_msg("Got text from user: $text")
		if ($main::Debug);
	
	return $text;
	
}



=head2 delete_msg_files FILE

DEPRECATED: Only still around because VOCPweb needs a rewrite - avoid using!



Deletes FILE (in inboxdir) and possible cached secondary version (pvf, wav, au) of FILE if 
the 'cachedir' (which must be a directory relative to and below inboxdir) option 
is set in vocp.conf (used with vocpweb). 
Returns the number of deleted files.

=cut

sub delete_msg_files {
	my $self = shift;
	my $msg = shift
		|| VOCP::Util::error("Must pass a msg file to delete to delete_msg_files()", $VOCP::Vars::Exit{'MISSING'});
	
	VOCP::Util::log_msg("delete_msg_files() called for $msg")
		if($main::Debug > 1);
	
	my ($file, $ext) = VOCP::Util::clean_filename($msg);
	
	my $filename = VOCP::Util::full_path("$file.$ext", $self->{'inboxdir'}, 'SAFE');
	
	VOCP::Util::log_msg("About to delete $filename")
		if($main::Debug);
		
	my $num = unlink $filename;
			
	VOCP::Util::log_msg("Seems there was a problem deleting $filename")
		unless ($num);
	
	# Total number deleted files
	my $total = $num;
	
	if ($self->{'cachedir'}) { #check for other (cached) versions of file
		my $cachedir = VOCP::Util::full_path($self->{'cachedir'}, $self->{'inboxdir'});
		my @cachefiles;

		my $pvffile = VOCP::Util::full_path("$file.pvf", $cachedir);
		my $wavfile = VOCP::Util::full_path("$file.wav", $cachedir);
		my $aufile  = VOCP::Util::full_path("$file.au", $cachedir);

		push @cachefiles, $pvffile
			if (-r $pvffile);
		push @cachefiles, $wavfile
			if (-r $wavfile);
		push @cachefiles, $aufile
			if (-r $aufile );
		
		if (scalar @cachefiles) {
		
			VOCP::Util::log_msg("Also deleting :" . join(", ", @cachefiles))
				if ($main::Debug);
			
			my $cnt = unlink @cachefiles ;
			
			
			VOCP::Util::log_msg("Seems there was a problem deleting one of: " . join(", ", @cachefiles))
				unless ($cnt == scalar @cachefiles);
				
			$total += $cnt;
		}
	}

	return $total;
	
}


sub Record {
	my $self = shift;
	my $message = shift;
	
	my $file = VOCP::Util::full_path($message, $self->{'messagedir'}, 'SAFE');
	
	return $self->{'voicedevice'}->record($file);
	
}


=head2 Beep

Tells vgetty to BEEP and returns the resulting 
vgetty response (whatever comes after BEEPING, should
be READY).

=cut

sub Beep {
	my $self = shift;
	
	return $self->{'voicedevice'}->beep($self->{'beep_frequency'}, $self->{'beep_length'});
	
}



sub connect {
	my $self = shift;
	
	return $self->{'voicedevice'}->connect();
}
	


sub disconnect {
	my $self = shift;
	$self->{'_isdisconnected'} = 1;
	return $self->{'voicedevice'}->disconnect();
}


=head2 shutdown [EXITSTATUSCODE]

Disconnects the voice device (if not already done with a call to disconnect() ) and
exits with exit code EXITSTATUSCODE if passed or 0.

=cut
sub shutdown {
	my $self = shift;
	my $exitStatus = shift || 0;
	
	VOCP::Util::log_msg("VOCP Shutdown called") if ($main::Debug);
	
	if ($self->{'voicedevice'} && ! $self->{'_isdisconnected'})
	{
		VOCP::Util::log_msg("VOCP Shutdown disconnecting from device") if ($main::Debug > 1);
	
		$self->{'voicedevice'}->disconnect();
		delete $self->{'voicedevice'};
	}
	
	sleep (1);
	exit ($exitStatus);
}
	
	
=head2 get_dtmf [INPUTMODE [PAUSE [NUMDIGITS]]]

Gets DTMF input from the caller, using INPUTMODE, waiting PAUSE seconds, expecting NUMDIGITS if specified

=cut

sub get_dtmf {
	my $self = shift;
	my $inputMode = shift;
	my $pause = shift;
	my $numDigits = shift; # optionally set number of digits to expect
	
	
	$self->inputMode($inputMode) if (defined $inputMode);
	
	$pause = $self->{'pause'} unless (defined $pause);
	
	VOCP::Util::log_msg("VOCP::get_dtmf() calling readnum with pause $pause") if ($main::Debug > 1);
	
	return $self->{'voicedevice'}->readnum(undef, $pause, $self->{'max_errors'}, $numDigits);
}
	
=head1

	#### Various functions ####

=head2 log_msg @MSG

Logs lines in MSG array to STDERR, including the progname and pid.

It is usefull to redirect STDERR to a log file in the driver (main)
program, such that all output from the module goes to the log file.

=cut

sub log_msg {
	my $self = shift;
	my @msg = @_;
	
	return VOCP::Util::log_msg(@msg);
	
}



=head1

####  Class functions  ####
	
Included in the module, these functions are independant of the
VOCP objects.  They are therefore called using VOCP::function_name().

=cut

=head2 rmd2pvf RMDFILE OUTPUTFILE

converts RMD file produced by modem to the universal 
intermediate step, the PVF file.

=cut

sub rmd2pvf {
	my $self = shift;
	my $filename = shift;
	my $pvffile = shift;		
	my $nooverwrite = shift; #optional
	
	if ($nooverwrite && -e $pvffile)
	{
		return (1, "rmd2pvf: $pvffile already exists");
	} else
	{
		return $self->X2pvf($filename, $pvffile, "rmd", $nooverwrite);
	}
	
}

=head2 X2pvf FILENAME OUTPUTPVF FORMAT [NOOVERWRITE]

The X2pvf function is used to convert from format X (see below) to the Portable Voice Format.  The PVF files are often 
used to create modem-dependant rmd (raw modem data) files.

FILENAME may be any file found on the system. The supported FORMATs for filename depend on the installed
XXXtopvf programs.  Bothe the pvftooldir and the vocp local dir (/usr/local/vocp) will be searched for a matching
XXXtopvf file.

For instance, calling:

$VocpObj->X2pvf("/home/me/list.txt", "/home/me/list.pvf", "txt");

will cause VOCP to search for a 'txttopvf' executable in pvftooldir and the VOCP local dir.  If found, 'txttopvf' will
be called to create the /home/me/list.pvf file.

There are no guarantees that this operation will succeed (the executable may not be found, problems may occur during 
execution, etc.)  Check the functions return values but, more importantly, select OUTPUTPVF files that are safe and do
not exist, then check that they've been created.

Returns a list (ERRORCODE, MESSAGE), where ERRORCODE is 0 on success.


=cut



sub X2pvf {
	my $self = shift;
	my $filename = shift;
	my $pvffile = shift;		
	my $format = shift;		
	my $nooverwrite = shift; # optional
	
	
	return VOCP::Util::X2pvf(	'inputfile'	=> $filename, 
					'outputfile'	=> $pvffile, 
					'inputformat'	=> $format, 
					'nooverwrite'	=> $nooverwrite, 
					'rmdsample' 	=> $self->{'rmdsample'},
					'pvftooldir'	=> $self->{'pvftooldir'});
					
}

=head2 pvf2X PVFFILE OUTPUTFILE FORMAT

converts PVFFILE to another format (FORMAT), producing OUTPUTFILE

=cut

sub pvf2X {
	my $self = shift;
	my $pvffile = shift;
	my $soundfile = shift;
	my $formattype = shift;
	my $options = shift || ""; # optional param to pass to pvftoX prog
	my $nooverwrite = shift; # optional 
	
	
	if ( (!$options) && ($formattype eq 'rmd'))
	{
		$options = $self->{'rmdformat'} . " " . $self->{'rmdcompression'};
	}
	
	return VOCP::Util::pvf2X($pvffile, $soundfile, $formattype, $options, $nooverwrite, $self->{'pvftooldir'});
	
}

1;
__END__

=head1 AUTHOR INFORMATION

LICENSE

    VOCP module, part of the VOCP voice messaging system.
    Copyright (C) 2000-2003 Patrick Deegan
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


Address bug reports and comments to: prog AT vocpsystem.com or come
and see us at http://www.psychogenic.com.

When sending bug reports, please provide the version of
VOCP.pm, the version of Perl, the version of your
mgetty/vgetty, and the name and version of the operating
system you are using.  If the problem is even remotely
modem dependent, please provide information about the
affected modems as well. 


=head1 CREDITS

Thanks very much to the vgetty developpers for making
VOCP system possible.

=head1 BUGS

No bugs reported for the moment...
If anything seems awry, please contact the author as
stated in the AUTHOR INFORMATION section.

=head1 SEE ALSO

If you are developping software using this module and
vgetty, make sure you thouroughly check the vgetty
documentation.

=cut

