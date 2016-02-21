package VOCP::Box;


use VOCP::Util;
use VOCP::Vars;
use VOCP::Message;
use VOCP::Box::MetaData;
use DirHandle;


use strict;

use vars qw {
		$VERSION
	};
	

$VERSION = $VOCP::Vars::VERSION;


=head1 VOCP::Box

=head1 NAME

	VOCP::Box - Represent a VOCP box.


=head1 SYNOPSIS

	use VOCP::Box;
	
	my $boxFactory = VOCP::Box::Factory->new('/path/to/inboxdir');

	%params = (
		'type'		=> 'mail',
		'number'	=> '100',
		'owner'		=> 'pat',
		'password'	=> 's3cr3t',
		'email'		=> 'somebox@psychogenic.com',
	);
	
	my $newBox = $boxFactory->newBox(%params);
	
	print $newBox->location() . " " . $newBox->message() . " " $newBox->owner() . "\n";
	
	my $messages = $newBox->listMessages();
	
	foreach my $msg (@{$messages})
	{
		# do something with each VOCP::Message object
	}
	
	# or
	
	my $idx = 1;
	while (my $msg = $newBox->fetchMessage($idx++))
	{
		# do something with each VOCP::Message object
	}

=head1 ABSTRACT

The VOCP::Box package contains a base VOCP::Box class from which other Box types are
derived, a VOCP::Box::Factory class used to instantiate derivative boxe objects and the various
VOCP::Box::XXX derived classes (one for each type of supported box - ie mail, pager,
command, faxondemand, script, none).


=head1 DESCRIPTION

The VOCP::Box class is used as an abstract base class for all 
VOCP::Box::{Mail,Pager,Command,Script,FaxOnDemand,None} boxes.  It is not meant to be
instantiated, only derived from.  It provides default behavior to derivative classes.




=head1 AUTHOR

LICENSE

    VOCP::Box module, part of the VOCP voice messaging system package.
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


=head1 Class Methods

=cut


=head2 new LOCATION %PARAMS

Creates a new instance, $PARAMS{'number'} must be passed in all cases.  Additional 
requirements may apply to derived types.

Returns a new blessed object.

=cut




####################################                            ######################################
####################################         VOCP::Box          ######################################
####################################                            ######################################


sub new {
	my $class = shift;
	my $location = shift; 	
	my %params = @_;
	
	
	
	VOCP::Util::error("All boxes must have a numerical box number set") 
			unless (defined $params{'number'} && $params{'number'} =~ /^\d+$/);


	foreach my $key (keys %params)
	{
		if ($params{$key} eq 'none')
		{
			delete $params{$key};
		}
	}

	my $self = {};
        
        bless $self, ref $class || $class;
        $self->{'number'} = "";
	$self->{'location'} = "";
	$self->{'messages'} = [];
	
	
	$self->location($location);
	$self->number($params{'number'});
	$self->message($params{'message'});
	$self->type($params{'type'});
	$self->password($params{'password'});
	$self->owner($params{'owner'});
	$self->branch(undef, $params{'branch'});
	$self->email($params{'email'});
	$self->autojump($params{'autojump'});
	$self->restricted($params{'restricted'});
	
	$self->name($params{'name'});
	$self->restrictFrom($params{'restrictFrom'});
	$self->restrictLoginFrom($params{'restrictLoginFrom'});
	$self->numDigits($params{'numDigits'});
	
	$self->init(\%params);
	
	my $autojump = $self->autojump();
	$self->isDeadEnd(1) unless (defined $autojump || $self->{'_numbranches'});
	
	
	$self->checkInit();
	
	return $self;
}


=head2 init

Called by new().

=cut

sub init {
	my $self = shift;
	my $params = shift;
	
}

=head2 checkInit

Called by new(), used in derived classes for additional requirements checks.

=cut

sub checkInit {
	my $self = shift;
	
	VOCP::Util::error("The checkInit() method must be overridden in VOCP::Box subclasses.");
}


=head2 location [NEWLOCATION]

Returns the box's location, optionally setting to
NEWLOCATION if passed.

=cut


sub location {
	my $self = shift;
	my $loc = shift; # optionally set

	if (defined $loc)
	{
		$self->{'location'} = $loc;
	}
	
	return $self->{'location'};
}


=head2 getDetails

Returns an href of the boxes details, with keys:
 

 'number'
 'type'
 'message'
 'password'
 'owner'
 'email'
 'autojump'
 'restricted'
 'branch'

Which may or may not be defined (only number and type are guaranteed to be present and defined)

=cut

sub getDetails {
	my $self = shift;
	
	my $ret = {
		'number' 	=> $self->number(),
		'type'		=> $self->type(),
		'message'	=> $self->message(),
		'password'	=> $self->password(),
		'owner'		=> $self->owner(),
		'email'		=> $self->email(),
		'autojump'	=> $self->autojump(),
		'restricted'	=> $self->restricted(),
		'branch'	=> $self->getBranchLine(),
		'name'		=> $self->name(),
		'numDigits'	=> $self->numDigits(),
		'restrictFrom'	=> $self->restrictFrom(),
		'restrictLoginFrom' => $self->restrictLoginFrom(),
	};
	
	return $ret;
}

=head2 number [SETTO]

Returns the box number, optionally setting to SETTO if passed.

=cut

sub number {
	my $self = shift;
	my $number = shift; # optionally set
	
	if (defined $number)
	{
		if ($number !~ /^\d+$/)
		{
			return VOCP::Util::error("Invalid number passed to VOCP::Box::number(): '$number'");
		}
		
		$self->{'number'} = $number;
		
	}
	
	return $self->{'number'};
}


=head2 message [SETTO]

Returns the box message, optionally setting to SETTO if passed.

=cut
sub message {
	my $self = shift;
	my $message = shift; # optionally set
	
	if (defined $message)
	{
		if ($message eq 'none')
		{
			delete $self->{'message'};
		} else {
			$self->{'message'} = $message;
		}
		
	}
	
	return $self->{'message'};
}


=head2 type [SETTO]

Returns the box type, optionally setting to SETTO if passed.

=cut

sub type {
	my $self = shift;
	my $type = shift; # optionally set
	
	if (defined $type)
	{
		if ($type eq 'none')
		{
			delete $self->{'type'};
		} else {
			$self->{'type'} = $type;
		}
		
	}
	
	return $self->{'type'};
}


=head2 password [SETTO]

Returns the box password (possibly encrypted), optionally setting to SETTO if passed.

=cut
sub password {
	my $self = shift;
	my $password = shift; # optionally set
	
	if (defined $password)
	{
		VOCP::Util::error("Password must consist of only [letters,digits,!#._-] for box " 
					. $self->number() . " ('$password')")
			unless ($password =~ /^[\w\d\/\!\#\.\_\-]+$/);

		if ($password eq 'none')
		{
			delete $self->{'password'} ;
		} else {
		
			$self->{'password'} = $password;
		}
		
	}
	
	return $self->{'password'};
}



=head2 checkPassword ATTEMPT


Returns a TRUE value if ATTEMPT matches the password
(exactly, encrypted or through dtmf_to_text), FALSE value
otherwise.


=cut
sub checkPassword {
	my $self = shift;
	my $try = shift || "";
	
	my $passwd = $self->password() || "";
	
	# Return true if they are equal
	return 1 if ($try eq $passwd);
	
	# Check if it is crypted and/or dtmf 'text' input
	return 1 if (crypt($try, $passwd) eq $passwd);
	
	# Check if we were entering "DTMF text"
	my $dtmftotext = VOCP::Util::dtmf_to_text($try) || "";
	return 1 if ( ($dtmftotext eq $passwd)
			|| (crypt($dtmftotext, $passwd) eq $passwd) );
	
	# All tests failed :(
	return 0;
	
}


=head2 owner [SETTO]

Returns the box owner, optionally setting to SETTO if passed.

=cut


sub owner {
	my $self = shift;
	my $owner = shift; # optionally set
	
	if (defined $owner)
	{
		if ($owner eq 'none')
		{
			delete $self->{'owner'};
		} else {
		
			$self->{'owner'} = $owner;
		}
		
	}
	
	return $self->{'owner'};
}



=head2 name [SETTO]

Returns the box name, optionally setting to SETTO if passed.

The box name is used for informational purposes and aids in keeping track of which
box is which.

=cut


sub name {
	my $self = shift;
	my $name = shift; # optionally set
	
	if (defined $name)
	{
		if ($name eq 'none')
		{
			delete $self->{'name'};
		} else {
		
			$self->{'name'} = $name;
		}
		
	}
	
	return $self->{'name'};
}



=head2 numDigits [SETTO]

Returns the box numDigits, optionally setting to SETTO if passed.

The numDigits is set to the number of digits to expect the caller to enter at this
box.  Many boxes can skip setting this value as it should default to 1.  All boxes will
switch to multi-digit (any number) mode if the first entered char is '*'.

=cut


sub numDigits {
	my $self = shift;
	my $numDigits = shift; # optionally set
	
	if (defined $numDigits)
	{
		if ($numDigits eq 'none')
		{
			delete $self->{'numDigits'};
		} else {
		
			$self->{'numDigits'} = $numDigits;
		}
		
	}
	
	return $self->{'numDigits'};
}



=head2 restrictFrom [SETTO]

Returns the box restrictFrom, optionally setting to SETTO if passed.  SETTO is treating as
a Perl regular expression when comparing to caller id numbers.

restrictFrom is used to restrict access to a box based on caller ID information.

=cut


sub restrictFrom {
	my $self = shift;
	my $restrictFrom = shift; # optionally set
	
	if (defined $restrictFrom)
	{
		if ($restrictFrom eq 'none')
		{
			delete $self->{'restrictFrom'};
		} else {
		
			$self->{'restrictFrom'} = $restrictFrom;
		}
		
	}
	
	return $self->{'restrictFrom'};
}



=head2 allowCNDaccess NUMBER

Tests whether the NUMBER passed matches the restrictFrom regex, if set.

Returns a true value if the NUMBER is allowed or if restrictFrom is not set,
false otherwise.

=cut

sub allowCNDaccess {
	my $self = shift;
	my $number = shift;
	
	unless (defined $self->{'restrictFrom'})
	{
		# allow access to anyone if restrictFrom isn't set.
		VOCP::Util::log_msg("No CND restrictions set for this box.")
			if ($main::Debug > 1);
		return 1;
	}
	
	if ($number =~ m/$self->{'restrictFrom'}/)
	{
		VOCP::Util::log_msg("Caller number '$number' matches box restrictFrom '$self->{'restrictFrom'}'")
			if ($main::Debug);
		return 1;
	}
	
	# restrictFrom is set and number is not a match.
	return 0;
}



=head2 restrictLoginFrom [SETTO]

Returns the box restrictLoginFrom, optionally setting to SETTO if passed.  SETTO is treating as
a Perl regular expression when comparing to caller id numbers.

restrictLoginFrom is used to restrict LOGIN access to a box based on caller ID information.  To restrict
public access to a box, use restrictFrom.

=cut


sub restrictLoginFrom {
	my $self = shift;
	my $restrictFrom = shift; # optionally set
	
	if (defined $restrictFrom)
	{
		if ($restrictFrom eq 'none')
		{
			delete $self->{'restrictLoginFrom'};
		} else {
		
			$self->{'restrictLoginFrom'} = $restrictFrom;
		}
		
	}
	
	return $self->{'restrictLoginFrom'};
}



=head2 allowCNDlogin NUMBER

Tests whether the NUMBER passed matches the restrictLoginFrom regex, if set.

Returns a true value if the NUMBER is allowed or if restrictFrom is not set,
false otherwise.

=cut

sub allowCNDlogin {
	my $self = shift;
	my $number = shift;
	
	unless (defined $self->{'restrictLoginFrom'})
	{
		# allow access to anyone if restrictFrom isn't set.
		VOCP::Util::log_msg("No CND restrictions set for logins to this box.")
			if ($main::Debug > 1);
		return 1;
	}
	
	if ($number =~ m/$self->{'restrictLoginFrom'}/)
	{
		VOCP::Util::log_msg("Caller number '$number' matches box restrictLoginFrom '$self->{'restrictLoginFrom'}'")
			if ($main::Debug);
		return 1;
	}
	
	# restrictLoginFrom is set and number is not a match.
	return 0;
}



=head2 branch NUMBER [SETTO]

Returns the branch for selection NUMBER, optionally setting to SETTO if passed.


=cut


sub branch {
	my $self = shift;
	my $num = shift;
	my $branch = shift; # optionally set
	
	
	$num = 1 unless (defined $num);
	
	VOCP::Util::log_msg("VOCP::Box::branch($num) called.")
		if ($main::Debug > 1);
	
	if (defined $branch && $branch ne 'none')
	{
		$self->setBranch($branch);
	}
	
	my $retVal;
	if (defined $self->{'branch'}->{$num})
	{
		$retVal =  $self->{'branch'}->{$num};
	}
	
	VOCP::Util::log_msg("VOCP::Box::branch() returning '$retVal'")
		if ($main::Debug > 1 && defined $retVal);
		
	return $retVal;
}

# setBranch - called internally by branch() when setting
sub setBranch {
	my $self = shift;
	my $branch = shift || return undef;
	
	my @branches = split (',', $branch);
	
	my $i;
	my $numbranches = 0;
	for ($i=1; $i <= scalar @branches; $i++) {
		# 2 possible formats:
		# XXX,YYY,ZZZ where pressing 1 jumps to XXX, 2 jumps to YYY ...
		# and
		# N=XXX,M=YYY,O=ZZZ where pressing N jumps to XXX, and M jumps to YYY...
		if ( $branches[$i-1] =~ /^(\d+)\s*=\s*(\d+)$/ ) { # Form N=XXX
			$self->{'branch'}->{$1} = $2;
			$numbranches++;
			
		} else { # No key defined, use position
			$self->{'branch'}->{$i} = $branches[$i - 1];
			$numbranches++;
		}
	}

	$self->{'_numbranches'} = $numbranches;
	return $numbranches;	
}


=head2 getBranchLine

Returns the a branch line suitable for use in (old style) config file.

=cut

sub getBranchLine {
	my $self = shift;
	
	return undef unless (defined $self->{'branch'});
	
	my @branches;
	foreach my $key (sort keys %{$self->{'branch'}})
	{
		$branches[scalar @branches] = "$key=" . $self->{'branch'}->{$key};
	}
	
	my $line = join(',', @branches);
	
	return $line;
}
	

=head2 numBranch

Returns the number of available branches (undef if none)

=cut

sub numBranch {
	my $self = shift;
	
	return undef unless (defined $self->{'_numbranches'});
	
	return $self->{'_numbranches'};
}


=head2 email [SETTO]

Returns the box email, optionally setting to SETTO if passed.

=cut


sub email {
	my $self = shift;
	my $email = shift; # optionally set
	
	if (defined $email)
	{
		if ($email eq 'none')
		{
			delete $self->{'email'};
		} else {
			$self->{'email'} = $email;
		}
		
	}
	
	return $self->{'email'};
}


=head2 autojump [SETTO]

Returns the box autojump, optionally setting to SETTO if passed.

=cut

sub autojump {
	my $self = shift;
	my $autojump = shift; # optionally set
	
	if (defined $autojump)
	{
		VOCP::Util::error("Can't set autojump to same number as box number ($autojump)")
			if ($autojump eq $self->{'number'});
		if ($autojump eq 'none')
		{
			delete $self->{'autojump'} ;
		} else {
		
			$self->{'autojump'} = $autojump;
		}
	}
	
	return $self->{'autojump'};
}


=head2 restricted [SETTO]

Returns the restricted box password, optionally setting to SETTO if passed.

=cut


sub restricted {
	my $self = shift;
	my $restricted = shift; # optionally set
	
	if (defined $restricted)
	{
		VOCP::Util::error("Restricted access password must consist of only digits")
			unless ($restricted =~ /^[\w\d]+$/);
			
		if ($restricted eq 'none')
		{
			delete $self->{'restricted'} ;
		} else {
		
			$self->{'restricted'} = $restricted;
		}
		
	}
	
	return $self->{'restricted'};
}

=head2 isMailbox [SETTO]

Returns the whether this box is a mail box, optionally setting to SETTO if passed.

=cut
sub isMailbox {
	my $self = shift;
	my $isMailbox = shift; # optionally set
	
	if (defined $isMailbox)
	{
		$self->{'isMailbox'} = $isMailbox;
		
	}
	
	return $self->{'isMailbox'};
}

=head2  isDeadEnd [SETTO]

Returns whether this box is a dead end, optionally setting to SETTO if passed.

=cut

sub isDeadEnd {
	my $self = shift;
	my $isDeadEnd = shift; # optionally set
	
	if (defined $isDeadEnd)
	{
		$self->{'isDeadEnd'} = $isDeadEnd;
		
	}
	
	return $self->{'isDeadEnd'};
}


=head2 numMessages [FORCEREFRESH]

Returns the number of messages in this box, optionally forcing a 
refresh (new count) if the FORCEREFRESH flag is passed TRUE.

=cut


sub numMessages {
	my $self = shift;
	my $forceRefresh = shift;
	
	
	if ( (! defined $self->{'count'} ) || $forceRefresh)
	{
		$self->fetchAllMessages();
	}
	
	return $self->{'count'};
}



=head2 listMessages [SORTBY[FORCEREFRESH]]

Returns an array ref of messages, optionally sorted by SORTBY (see fetchAllMessages() for valid SORTBY values).

FORCEREFRESH, when true, causes a forced call to fetchAllMessages (which is 
skipped if 'count' is defined.

=cut

sub listMessages {
	my $self = shift;
	my $sortBy = shift;
	my $forceRefresh = shift;
	
	if ( (! defined $self->{'count'} ) || $forceRefresh || $sortBy ne $self->{'_sortby'})
	{
		$self->fetchAllMessages($sortBy);
	}
	
	return $self->{'messages'};
}


=head2 fetchMessageByID ID [FORCEREFRESH]

Searches for a message with id (number) equal to ID.  Returns the VOCP::Message object
if found, undef otherwise.

=cut


sub fetchMessageByID {
	my $self = shift;
	my $id = shift;
	my $forceRefresh = shift;
	
	if ($forceRefresh)
	{
		$self->fetchAllMessages();
	} else {
		$self->numMessages(); # ensures we have messages in memory
	}
	
	unless (defined $id)
	{
		return VOCP::Util::error("VOCP::Box::fetchMessageByID() Must pass an ID!");
	}
	
	my $foundMessage;
	my $i=0;
	while (defined $self->{'messages'}->[$i] && (! $foundMessage)) 
	{
		my $msgID = $self->{'messages'}->[$i]->number();
		$foundMessage = $self->{'messages'}->[$i] if ($msgID eq $id);
		$i++;
	}
	
	return $foundMessage;
}




=head2 fetchMessage [INDEX]

Returns Message object at INDEX

You can use a simple

 
my $message = $box->fetchMessage($idx);

But may also safely use a loop like:

 
my $i=1;
while (my $message = $box->fetchMessage($i++))
{
	# do stuff...
}

As the method will return undef when $i goes out of bounds. 

NOTE: Message indexes start at 1.


=cut

sub fetchMessage {
	my $self = shift;
	my $index = shift ;
	
	VOCP::Util::error("VOCP::Box::fetchMessage() - Must pass a message index.")
		unless (defined $index);
	
	
	VOCP::Util::error("VOCP::Box::fetchMessage() - Message index begins at 1 (not 0).")
		unless ($index >= 0);
	
	my $maxIdx = $self->numMessages(); # ensures we have messages in memory
	if ($index > $maxIdx)
	{
		return undef;
	}
	
	my $idx = $index - 1;
	
	VOCP::Util::error("VOCP::Box::fetchMessage() - Message '$index' should be defined but is not")
		unless (defined $self->{'messages'}->[$idx]);
	
	
	return $self->{'messages'}->[$idx];
}


=head2 fetchAllMessages [SORTBY]

Fetch all messages for this box, sorting by SORTBY.

SORTBY may be any combination of DATE/INVDATE, READ, FLAG

eg. 'READ|FLAG' or 'INVDATE'.

Defaults to DATE.

=cut

sub fetchAllMessages {
	my $self = shift;
	my $sortby = shift || $self->{'_sortby'} || 'DATE';
	
	VOCP::Util::error("Both 'number' and 'location' must be set to fetchAllMessages()")
		unless (defined $self->{'location'} && defined $self->{'number'});
	
	$self->{'messages'} = [];
	
	my $msgdir = DirHandle->new($self->{'location'}) || VOCP::Util::error("Could not open " . $self->{'location'} . ": $!");
	
	$self->{'_sortby'} = $sortby;
	my $box = $self->{'number'};
	my %matchingFiles;
	while (my $afilename = $msgdir->read())
	{
		next unless ($afilename =~ m|([\w\d\._/]*$box-(\d+)(-([\w\d]+))?\.rmd$)|);
		
		$afilename = $1;
		
		my $absName = VOCP::Util::full_path($afilename, $self->{'location'});
		
		my $message = VOCP::Message->new($absName);
		
		my $timekey = $message->getAttrib('time');
		
		if ($sortby =~ m|INVDATE|)
		{
			$timekey = 9000000000 - $timekey;
		} 
		
		if ($sortby =~ m|READ|i)
		{
			$timekey = "r$timekey" if ($message->flagRead());
		}
		
		if ($sortby =~ m|FLAG|i)
		{
			$timekey = "f$timekey" if ($message->flagFlag());
		}
		 
		unless (defined $matchingFiles{$timekey})
		{
			$matchingFiles{$timekey} = [];
		}
		
		push @{$matchingFiles{$timekey}}, $message;
	}
	$msgdir->close();
	
	my $count = 0;
	# Add files to the file array, sorted by key
	foreach my $key (sort keys %matchingFiles)
	{
		foreach my $msg (@{$matchingFiles{$key}})
		{
			$self->{'messages'}->[$count++] = $msg;
		}
	}
	$self->{'count'} = $count;
	
	return $count;
	
}


sub getLastMessageNumber {
	my $self = shift;
	
	# Force a new fetch, just in case.
	
	my $messages = $self->listMessages($self->{'_sortby'}, 'FORCEREFRESH');
	
	my $highestNum = 0;
	
	foreach my $msg (@{$messages})
	{
		my $num = $msg->number();
		if ($num > $highestNum)
		{
			$highestNum = $num;
		}
	}
	
	my $retNum = $highestNum;
	my $numdigits = length($highestNum);
	$retNum = '0' x (4 - $numdigits) . $highestNum
		if ($numdigits < 4);
	
	return $retNum;
}

sub getLastMessageName {
	my $self = shift;
	
	my $msgnum = $self->getLastMessageNumber();
	
	my $msgName = $self->{'location'};
	$msgName .= '/' unless ($msgName =~ m|/$|);
	$msgName .= $self->{'number'} . '-' . $msgnum . '.rmd';
	
}


=head2 createNewMessageName

Returns a filename suitable for a new message. (fullpath)

=cut

sub createNewMessageName {
	my $self = shift;
	
	# Force a new fetch, just in case.
	
	my $messages = $self->listMessages($self->{'_sortby'}, 'FORCEREFRESH');
	
	my $highestNum = 0;
	
	foreach my $msg (@{$messages})
	{
		my $num = $msg->number();
		if ($num > $highestNum)
		{
			$highestNum = $num;
		}
	}
	
	my $newNum = $highestNum + 1;
	my $numdigits = length($newNum);
	$newNum = '0' x (4 - $numdigits) . $newNum
		if ($numdigits < 4);
	
	my $newName = $self->{'location'};
	$newName .= '/' unless ($newName =~ m|/$|);
	$newName .= $self->{'number'} . '-' . $newNum . '.rmd';
	
	return $newName;
} 

=head2 createNewMessageFileHandle

Better, safer, version of createNewMessageName - this method actually opens (O_EXCL|O_CREAT) a file in 0600 mode
and returns the array ($messageFileHandle, $messageFileName).

Use it.

=cut

sub createNewMessageFileHandle {
	my $self = shift;
	
	my $maxTry = 100;
	my $try = 0;
	my ($messageFileHandle, $messageFileName);
	
	require Fcntl unless defined &Fcntl::O_RDWR;
	
	$messageFileHandle = FileHandle->new();
	my $oldumask = umask(0077);
	my $fail;
	do {
		$fail = 1;
		$messageFileName = $self->createNewMessageName(); 
		if ($messageFileHandle->open($messageFileName, Fcntl::O_RDWR()|Fcntl::O_CREAT()|Fcntl::O_EXCL()))
		{
			$fail = 0;
		}
		
		$try++;
		
	} while ($fail && $try <= $maxTry);
	
	umask($oldumask);
	if ($try > $maxTry)
	{
		return undef;
	}
	
	return ($messageFileHandle, $messageFileName);
	
}


=head2 deleteMessage INDEX

Delete's message INDEX from memory AND from the hard drive.  Returns 1 if sucessful.

Remember that the first message is message index 1.  If you want to be sure you're deleting
the right message, you can just fetch the VOCP::Message object

 
 my $messageObject = $box->fetchMessage($INDEX);

And then call delete directly on it:

 
 $messageObject->delete();

But if you do this, remember to refresh the box using 

 $box->refresh();


=cut

sub deleteMessage {
	my $self = shift;
	my $index = shift;
	
	my $message = $self->fetchMessage($index);
	
	VOCP::Util::error("VOCP::Box::deleteMessage() - no message at index $index")
		unless ($message);
	
	return $self->_doDelMessage($message);
}



sub deleteMessageByID {
	my $self = shift;
	my $id = shift;
	
	my $messageObject = $self->fetchMessageByID($id);
	
	VOCP::Util::error("VOCP::Box::deleteMessageByID - could not find a message '$id'")
		unless ($messageObject);
	
	return $self->_doDelMessage($messageObject);
}


sub _doDelMessage {
	my $self = shift;
	my $msgObj = shift || return VOCP::Util::error("VOCP::Box::_doDelMessage - Must pass a VOCP::Message object");
	
	my $metaData = $self->metaData();
	
	$metaData->deleteMessageData($msgObj->number());
	
	$msgObj->delete();
	
	$metaData->save();
	
	return $self->numMessages('FORCEREFRESH');
}


sub deleteAllMessages {
	my $self = shift;
	
	my $metaData = $self->metaData();
	my $delCount = 0;
	foreach my $msgObj ( @{$self->{'messages'}})
	{
		$metaData->deleteMessageData($msgObj->number());
		$msgObj->delete();
		$delCount++;
	}
	
	$metaData->save();
	
	return $delCount;	
}


=head2 refresh

Clears the memory cach of VOCP::Message objects - messages will be refetch on next fetch/list/count

=cut

sub refresh {
	my $self = shift;
	
	delete $self->{'count'};
	delete $self->{'messages'};
}



=head2 metaData 

Gets/sets the box metadata object

=cut

sub metaData {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{
		my $type = ref $setTo;
		return VOCP::Util::error("VOCP::Box::metaData() - trying to set to invalid object '$type'")
			unless ($type eq 'VOCP::Box::MetaData');
			
		$self->{'_metaData'} = $setTo;
	}
	
	unless ($self->{'_metaData'})
	{
		my $params = {
				'inboxdir'	=> $self->location(),
			};
			
		$self->{'_metaData'} = VOCP::Box::MetaData->new($self->number(), $params);
	}
	
	return $self->{'_metaData'};
}


sub DESTROY {
	my $self = shift;
	
	if ($self->{'_metaData'})
	{
		VOCP::Util::log_msg("VOCP::Box destructor called, saving meta data")
			if ($main::Debug);
			
		$self->{'_metaData'}->save();
	}
	
} 



######################### Private VOCP::Box methods (may be used by subclasses, just not part of public interface)


sub fileExists {
	my $self = shift;
	my $file = shift;
	
	
	VOCP::Util::error("File for box " . $self->{'number'} 
			. " ('$file') not found.")
			unless (-e $file);
	
	
	return 1;
}

sub fileIsExecutable {
	my $self = shift;
	my $file = shift;
	
	
	$self->fileExists($file) || die "No such file $file";
	
	VOCP::Util::error("File for box " . $self->{'number'} 
			. " ('$file') not executable.")
			unless (-x $file);
			
	return 1;
}


sub fileIsSafeExecutable {
	my $self = shift;
	my $script = shift;
	
	$self->fileIsExecutable($script) || die "File not executable '$script'";
	
	my $owner = $self->owner() 
			|| VOCP::Util::error("VOCP::Box::safeExe() - No owner set for script box $self->{'number'}");
		
	my ($name,$passwd,$uid,$gid,
                     $quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam($owner);

	VOCP::Util::error("VOCP::Box::safeExe() - Can't find box $self->{'number'} owner '$owner' on system.")
		unless ($name && ($name eq $owner));
	
	
	my ($dev,$ino,$mode,$nlink,$scriptuid,$scriptgid,$rdev,$size,
            $atime,$mtime,$ctime,$blksize,$blocks)
                         = stat($script);
	my ($ldev,$lino,$lmode,$lnlink,$lscriptuid,$lscriptgid,$lrdev,$lsize,
            $latime,$lmtime,$lctime,$lblksize,$lblocks)
                         = lstat($script);

	unless ($dev == $ldev)
	{
		VOCP::Util::error("VOCP::Box::safeExe() - the script assigned to box $self->{'number'} is actually a "
				. "soft link - please set the script to the actual file to execute.");
	}
	
	if ($scriptuid != $uid && $scriptuid != 0)
	{
	 
		VOCP::Util::error("VOCP::Box::safeExe() - Script set for box $self->{'number'} ($script) is "
				. "neither owned by the box owner ($owner) or the root user.  Unsafe badness - please fix.");
	}
	
	
	return 1;
}













####################################                            ######################################
####################################     VOCP::Box::Factory     ######################################
####################################                            ######################################

package VOCP::Box::Factory;
use VOCP::Util;

use strict;

=head1 VOCP::Box::Factory

VOCP::Box::Factory - encapsulates VOCP::Box creation.

=head1 SYNOPSIS

 	use VOCP::Box;
 
	my $boxFactory = VOCP::Box::Factory->new('/path/to/inboxdir');

	%params = (
		'type'		=> 'mail',
		'number'	=> '100',
		'owner'		=> 'pat',
		'password'	=> 's3cr3t',
		'email'		=> 'somebox@psychogenic.com',
	);
	
	my $newBox = $boxFactory->newBox(%params);



=head1 ABSTRACT

Provides a factory to generate appropriate VOCP::Box derived classes, based on the
passed type.

=cut


=head2 new LOCATION

Creates a new factory for boxes which store their messages in LOCATION.

=cut

sub new {
	my $class = shift;
	my $location = shift;
	
	my $self = {};
        
        bless $self, ref $class || $class;

	VOCP::Util::error("Must pass a location for boxes to VOCP::Box::Factory::new()")
		unless ($location);
	
	$self->{'location'} = $location;
	return $self;
}


=head2 newBox %PARAMS

Creates a new box of type $PARAMS{'type'}.  This box will be an object of an 
appropriate class derived from VOCP::Box.

Other parameters may be required, depending on the box type.
Certain restrictions apply, must be 18 years of age or older to participate.

=cut

sub newBox {
	my $self = shift;	
	my %params = @_;

	my $type = $params{'type'};
	 
	if ( (! $type) || $type eq 'none')
	{
		return VOCP::Box::None->new($self->{'location'}, %params);
	} elsif ($type eq 'mail') {
		return VOCP::Box::Mail->new($self->{'location'}, %params);
	} elsif ($type eq 'pager') {
		return VOCP::Box::Pager->new($self->{'location'}, %params);
	} elsif ($type eq 'script') {
		return VOCP::Box::Script->new($self->{'location'}, %params);
	} elsif ($type eq 'command') {
		return VOCP::Box::Command->new($self->{'location'}, %params);
	} elsif ($type eq 'faxondemand') {
		return VOCP::Box::FaxOnDemand->new($self->{'location'}, %params);
	} elsif ($type eq 'group') {
		return VOCP::Box::Group->new($self->{'location'}, %params);
	} elsif ($type eq 'receivefax') {
		return VOCP::Box::ReceiveFax->new($self->{'location'}, %params);
	} elsif ($type eq 'exit') {
		return VOCP::Box::Exit->new($self->{'location'}, %params);
	} else {
		return VOCP::Util::error("VOCP::Box::Factory::newBox() Unknown box type to create '$type'");
	}
	
}











####################################                            ######################################
####################################       VOCP::Box::None      ######################################
####################################                            ######################################


=head1 VOCP::Box::None

VOCP::Box derived class for "none" type boxes.  Minimum requirements: must either have a message or an 
autojump set.

=cut

package VOCP::Box::None;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;

sub init {
	my $self = shift;
	
	$self->isMailbox(0);
}

sub checkInit {
	my $self = shift;
	
	# none boxes must have message or autojump set
	my $autojump = $self->autojump();
	
	VOCP::Util::error("'none' box "  . $self->{'number'} 
			. " must have either a message or autojump set.") unless ($self->message() || defined $autojump);
			
	$self->isDeadEnd(1) unless (defined $autojump || $self->{'_numbranches'});
	
	return 1;
	
}



####################################                            ######################################
####################################       VOCP::Box::Mail      ######################################
####################################                            ######################################


=head1 VOCP::Box::Mail


VOCP::Box derived class for "mail" type boxes.  Minimum requirements: must have a password set.

=cut

package VOCP::Box::Mail;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;

sub init {
	my $self = shift;
	
	$self->isMailbox(1);
}

sub checkInit {
	my $self = shift;
	
	# none boxes must have message or autojump set
	VOCP::Util::error("'mail' box "  . $self->{'number'} 
			. " must have a password set.") unless ($self->password());
	
	return 1;
	
}











####################################                            ######################################
####################################       VOCP::Box::Pager     ######################################
####################################                            ######################################




=head1 VOCP::Box::Pager


VOCP::Box derived class for "pager" type boxes.  Minimum requirements: must have an email set.

=cut


package VOCP::Box::Pager;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;

sub init {
	my $self = shift;
	
	$self->isMailbox(0);
	$self->isDeadEnd(1);
}

sub checkInit {
	my $self = shift;
	
	# none boxes must have message or autojump set
	VOCP::Util::error("'pager' box "  . $self->{'number'} 
			. " must have an email set.") unless ($self->email());
	
	return 1;
	
}














####################################                            ######################################
####################################     VOCP::Box::Command     ######################################
####################################                            ######################################



=head1 VOCP::Box::Command


VOCP::Box derived class for "command" shell type boxes.  Minimum requirements: must have a password and an owner set.
Cannot set autojump.

=cut


package VOCP::Box::Command;
use base qw (VOCP::Box);
use VOCP::Util;


use vars qw {
		$ValidInput
		$ValidReturn
	};


$ValidInput = 'none|raw|text';
$ValidReturn = 'exit|output|file|tts|sendfax';

use strict;
	
sub init {
	my $self = shift;
	my $params = shift;
	
	
	if ($params->{'commanddir'})
	{
		
		$self->{'commanddir'} = $params->{'commanddir'} ;
		
		$self->{'commanddir'} .= '/' unless ($self->{'commanddir'} =~ m|/$|);
	}
	
	if ($params->{'commands'})
	{
		while (my ($comsel, $comInit) = each %{$params->{'commands'}})
		{
			unless ($comInit->{'input'} =~ m#^(|$ValidInput)$#)
			{
				VOCP::Util::log_msg("VOCP::Box::Command::init(): invalid input type "
							. "$comInit->{'input'} for $comsel - skipping.");
				next;
			}
			
			unless ($comInit->{'return'} =~ m#^($ValidReturn)$#)
			{
				VOCP::Util::log_msg("VOCP::Box::Command::init(): invalid return type "
							. "$comInit->{'return'} for $comsel - skipping.");
				next;
			}
			
			unless ($comInit->{'run'})
			{
				VOCP::Util::log_msg("VOCP::Box::Command::init(): no run prog set for $comsel  - skipping.");
				next;
			}
			
			my $torun = $comInit->{'run'};
			
			$torun =~ s/\s*([^\s]+).*/$1/;
			
			$torun = $self->{'commanddir'} . $torun unless ($torun =~ m|/$|);
			
			
			
			
			$self->fileIsSafeExecutable($torun) 
				|| VOCP::Util::error("VOCP::Box::Command::init() bad 'run' param for $self->{'number'} selection $comsel");
			
			$self->selection($comsel, $comInit->{'input'}, $comInit->{'return'}, $comInit->{'run'});
		}
	}
	
	$self->isMailbox(0);
}

sub checkInit {
	my $self = shift;
	
	# none boxes must have message or autojump set
	VOCP::Util::error("'command' box "  . $self->{'number'} 
			. " must have a password and an owner set.") unless ($self->password() && $self->owner());

	my $autojump = $self->autojump();
	
	VOCP::Util::error("'command' box "  . $self->{'number'} 
			. ": Can not set autojump or branching for command boxes.") if ($self->{'_numbranches'} || defined $autojump);
			
	
	return 1;
	
}

=head2 selection SELECTION [INPUT RETURN RUN]

Returns an href with info concerning the command to execute for selection SELECTION in this 
command box.  The keys to this returned href are:

 'selection'
 'input'
 'return'
 'run'	

if INPUT ('none', 'raw', 'text'), RETURN ('exit', 'output', 'file', 'tts') and RUN are passed, will 
set selection SELECTION up to run specified RUN command.

=cut

sub selection {
	my $self = shift;
	my $selection = shift;
	my $input = shift; #optional - can be 'none', 'raw' or 'text'
	my $return = shift; # optional - can be 'exit', 'output', 'file' oc 'tts'
	my $run = shift; #optional
	
	return undef unless (defined $selection);
	
	VOCP::Util::error("Can't use command box "  . $self->{'number'} 
			. " selection with non-numeric selection: $selection")
		unless ($selection =~ m|^\d+$|);
	
	if ($run)
	{
		# setting
		if ($run =~ m|/../| || $run !~ m|^[\s\w\d/\\_.+-]+$|) { #Suspicious looking command
		
			VOCP::Util::error("Command '$selection' for box "  . $self->{'number'} 
			. " did not pass untaint - '$run'");
			
		}
		
		$input ||= 'none';
		
		VOCP::Util::error("Command '$selection' for box "  . $self->{'number'} 
			. " invalid input '$input' - must be none|raw|text.")
				unless ($input =~ m/^(|$ValidInput)$/);
		$input = $1;
		
		
		VOCP::Util::error("Command '$selection' for box "  . $self->{'number'} 
			. " invalid return '$return' - must be $ValidReturn.")
				unless  ($return =~ m/^($ValidReturn)$/);
		
		$return = $1;
		
		$self->{'commands'}->{$selection}->{'input'} = $input;
		$self->{'commands'}->{$selection}->{'return'} = $return;
		$self->{'commands'}->{$selection}->{'run'} = $run;
	}
	
	return undef unless (defined $self->{'commands'}->{$selection});
	
	my $ret = {
		'selection'	=> $selection,
		'input'		=> $self->{'commands'}->{$selection}->{'input'},
		'return' 	=> $self->{'commands'}->{$selection}->{'return'},
		'run'		=> $self->{'commands'}->{$selection}->{'run'},
	};
	
	
	return $ret;
}


=head2 getAllSelections 

Returns an array ref of detail info from a call to selection() for each
available selection in this command shell box.

=cut

sub getAllSelections {
	my $self = shift;
	
	return [] unless (defined $self->{'commands'});
	
	my @selections;
	
	foreach my $sel (sort keys %{$self->{'commands'}})
	{
		$selections[scalar @selections] = $self->selection($sel);
	}
	
	return \@selections;
}


=head2 numSelections

Returns the number of available selections for this command shell box.

=cut

sub numSelections {
	my $self = shift;
	
	return 0 unless (defined $self->{'commands'});
	
	my @selections = (keys %{$self->{'commands'}});
	
	return scalar @selections;
}


=head2 deleteSelection SELECTION

Destroys information relative to selection SELECTION in this command shell box.

=cut
sub deleteSelection {
	my $self = shift;
	my $selection = shift || return undef;
	
	VOCP::Util::error("deleteSelection(): Can't use command box "  . $self->{'number'} 
			. " selection with non-numeric selection: $selection")
		unless ($selection =~ m|^\d+$|);
	
	return undef unless (defined $self->{'commands'}->{$selection});
	
	delete $self->{'commands'}->{$selection};
	
	return 1;
}

=head2 deleteAllSelections

Destroys information relative to ALL selections in this command shell box.

=cut

sub deleteAllSelections {
	my $self = shift;
	
	return undef unless (defined $self->{'commands'});
	my $count = 0;
	
	foreach my $sel (keys %{$self->{'commands'}})
	{
		$self->deleteSelection($sel);
		$count++;
	}
	
	return $count;
}
		

=head2 getDetails

Returns an href of the boxes details, with keys:
 

 'number'
 'type'
 'message'
 'password'
 'owner'
 'email'
 'autojump'
 'restricted'
 'branch'
 'commands' => {  
 			SELECTION1	=> {
						'selection'	=> SELECTION1,
						'input'		=> 'none',
						'return'	=> 'file',
						'run'		=> 'somescript.pl',
					},
					
			SELECTION2	=> { ... },
			
		}

Which may or may not be defined (only number and type are guaranteed to be present and defined)

=cut

sub getDetails {
	my $self = shift;
	
	
	my $ret = $self->SUPER::getDetails();
	
	my $commandSelections = $self->getAllSelections();
	
	foreach my $selection (@{$commandSelections})
	{
		$ret->{'commands'}->{$selection->{'selection'}} = $selection;
	}
	
	
	return $ret;
}















####################################                            ######################################
####################################      VOCP::Box::Script     ######################################
####################################                            ######################################





=head1 VOCP::Box::Script


VOCP::Box derived class for "script" type boxes.  Script boxes are somewhat like command shell boxes, except that:

 
- The script box is PUBLIC - any caller can execute the code simply by accessing the box through the
  public interface.
- Only is single command is set per box 
- The command is executed upon entering the box (after any configure box message is played) 


Minimum requirements: Script boxes must have a script (duh) and an owner (the script is run AS THIS USER)

=cut


package VOCP::Box::Script;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;




use vars qw {
		$ValidInput
		$ValidReturn
	};
	
$ValidInput = 'none|raw|text';
$ValidReturn = 'exit|output|file|tts|sendfax';


sub init {
	my $self = shift;
	my $params = shift;
	
	$self->{'script'} = $params->{'script'};
	$self->input($params->{'input'});
	$self->return($params->{'return'});
	
	my $autojump = $self->autojump();
	$self->isDeadEnd(1) unless (defined $autojump || $self->{'_numbranches'});
	
}

		
sub checkInit {
	my $self = shift;
	
	
	my $owner = $self->owner();
	# none boxes must have message or autojump set
	VOCP::Util::error("'script' box "  . $self->{'number'} 
			. " must have owner set.") unless ($owner);
			
	my ($name,$passwd,$uid,$gid,
                      $quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam($owner);
		      
	VOCP::Util::error("'script' box " . $self->{'number'} 
			. " must have a VALID system owner set (not '$owner')") unless ($name && ($name eq $owner));
			
			

	# Check that we have a script
	VOCP::Util::error("'script' box " . $self->{'number'} 
			. " must have a script set.")
			unless ($self->{'script'});
			
	# Validate that the script is valid by resetting it
	
	$self->script($self->{'script'});
	
	return 1;
	
}


sub input {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{
		
		VOCP::Util::error("VOCP::Box::Script::input(): invalid input type specified ('$setTo')")
			unless ($setTo =~ m/^$ValidInput$/);
		$self->{'input'} = $setTo;
	}
	
	return $self->{'input'};
}

sub return {
	my $self = shift; 
	my $setTo = shift;
	
	if (defined $setTo)
	{
		
		VOCP::Util::error("VOCP::Box::Script::return(): invalid return type specified ('$setTo')")
			unless ($setTo =~ m/^$ValidReturn$/);
		$self->{'return'} = $setTo;
	}
	
	return $self->{'return'} || 'exit';
}


sub script {
	my $self = shift;
	my $script = shift; # optionally set
	
	if (defined $script)
	{
		VOCP::Util::error("VOCP::Box::Script::script() - Script set for box $self->{'number'} ($script) is "
					. "unsafe - please fix.")
			unless ($self->fileIsSafeExecutable($script));
			
		
		$self->{'script'} = $script;
	}
	
	return $self->{'script'};
}




=head2 getDetails

Returns an href of the boxes details, with keys:
 

 'number'
 'type'
 'message'
 'password'
 'owner'
 'email'
 'autojump'
 'restricted'
 'branch'
 'script'	 

Which may or may not be defined (only number and type are guaranteed to be present and defined)

=cut

sub getDetails {
	my $self = shift;
	
	
	my $ret = $self->SUPER::getDetails();
	
	
	$ret->{'script'} = $self->script();
	$ret->{'input'} = $self->input();
	$ret->{'return'} = $self->return();
	
	return $ret;
}













####################################                            ######################################
####################################    VOCP::Box::FaxOnDemand  ######################################
####################################                            ######################################




=head1 VOCP::Box::FaxOnDemand


VOCP::Box derived class for "faxondemand" type boxes.  Minimum requirements: cannot have autojump or branching set.

Should have a file2Fax set using file2Fax().


=cut


package VOCP::Box::FaxOnDemand;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;

sub init {
	my $self = shift;
	my $params = shift;
	
	if ($params->{'file2fax'})
	{
		$self->file2Fax($params->{'file2fax'});
	}
	
	$self->isMailbox(0);
	$self->isDeadEnd(1);
}

sub checkInit {
	my $self = shift;
	
	my $autojump = $self->autojump();
	
	VOCP::Util::error("'faxondemand' box "  . $self->{'number'} 
			. ": Can not set autojump or branching for faxondemand boxes.") if ($self->{'_numbranches'} || defined $autojump);
			
	VOCP::Util::error("'faxondemand' box " . $self->{'number'} 
			. ' must have a file2fax set.')
			unless ($self->{'file2fax'});
			
	
	return 1;
}

=head2 file2Fax [NEWFILE]

Returns the full path filename of file to fax when callers access this fax on demand box.

If the optional (full path) NEWFILE is passed, sets the file to fax to NEWFILE.

=cut

sub file2Fax {
	my $self = shift;
	my $file = shift;
	
	if (defined $file)
	{
		VOCP::Util::error("'faxondemand' box "  . $self->{'number'} 
			. ": File to fax must have absolute path ($file)")
			unless ($file =~ m|^/|);
	
		$self->{'file2fax'} = $file;
	}
	
	return $self->{'file2fax'};
}



=head2 getDetails

Returns an href of the boxes details, with keys:
 

 'number'
 'type'
 'message'
 'password'
 'owner'
 'email'
 'autojump'
 'restricted'
 'branch'
 'file2fax'	 

Which may or may not be defined (only number and type are guaranteed to be present and defined)

=cut

sub getDetails {
	my $self = shift;
	
	
	my $ret = $self->SUPER::getDetails();
	
	
	$ret->{'file2fax'} = $self->file2Fax();
	
	return $ret;
}

















####################################                            ######################################
####################################       VOCP::Box::Group     ######################################
####################################                            ######################################




=head1 VOCP::Box::Group


VOCP::Box derived class for "group" type boxes. These boxes act as mailing lists, distributing voice messages
to any number of existing mail type boxes. Minimum requirements: cannot have autojump or branching set.

Should have a file2Fax set using file2Fax().


=cut


package VOCP::Box::Group;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;

sub init {
	my $self = shift;
	my $params = shift;
	
	if ($params->{'members'})
	{
		$self->members($params->{'members'});
	}
	
	$self->isMailbox(0);
	$self->isDeadEnd(1);
}

sub checkInit {
	my $self = shift;
	
	my $autojump = $self->autojump();
	
	VOCP::Util::error("'group' box "  . $self->{'number'} 
			. ": Can not set autojump or branching for group boxes.") if ($self->{'_numbranches'} || defined $autojump);
			
	
	unless ($self->{'members'} =~ m/\d+/)
	{
		VOCP::Util::error("'group' box " . $self->{'number'} . ': Needs at least 1 member set.');
	}
	
	return 1;
}

=head2 members [MEMBERS]

Returns a comma delimited string of member box numbers.  Set to MEMBERS when passed

=cut

sub members {
	my $self = shift;
	my $members = shift;
	
	if (defined $members)
	{
		VOCP::Util::error("'group' box "  . $self->{'number'} 
			. ": Member list must be a comma seperated list of numerical values only ($members)")
			unless ($members =~ m|^[\d\s,]+$|);
	
		$self->{'members'} = $members;
	}
	
	return $self->{'members'};
}


=head2 getMembersArray

Returns an array ref of all member boxnumbers.

=cut

sub getMembersArray {
	my $self = shift;
	
	my @list;
	return \@list unless ($self->{'members'} =~ /\d+/);
	
	@list = split(/\s*,\s*/, $self->{'members'});
	
	return \@list;
}



=head2 getDetails

Returns an href of the boxes details, with keys:
 

 'number'
 'type'
 'message'
 'password'
 'owner'
 'email'
 'autojump'
 'restricted'
 'branch'
 'members'	 

Which may or may not be defined (only number and type are guaranteed to be present and defined)

=cut

sub getDetails {
	my $self = shift;
	
	
	my $ret = $self->SUPER::getDetails();
	
	
	$ret->{'members'} = $self->members();
	
	return $ret;
}





####################################                            ######################################
####################################    VOCP::Box::ReceiveFax   ######################################
####################################                            ######################################




=head1 VOCP::Box::ReceiveFax


VOCP::Box derived class designed to allow callers to send a fax after accessing it.  Can have a message or
not and have no other conditions.  VOCP will exit after this box is accessed.


=cut


package VOCP::Box::ReceiveFax;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;

sub init {
	my $self = shift;
	my $params = shift;
	
	$self->isMailbox(0);
	$self->isDeadEnd(1);
}

sub checkInit {
	my $self = shift;
	
	return 1;
}




####################################                            ######################################
####################################        VOCP::Box::Exit     ######################################
####################################                            ######################################




=head1 VOCP::Box::Exit


VOCP::Box derived class designed to allow the call to be terminated at any point.  May have a message set
(eg "goodbye").  VOCP will exit after this box is accessed.


=cut


package VOCP::Box::Exit;
use base qw (VOCP::Box);
use VOCP::Util;

use strict;

sub init {
	my $self = shift;
	my $params = shift;
	
	$self->isMailbox(0);
	$self->isDeadEnd(1);
}

sub checkInit {
	my $self = shift;
	
	return 1;
}


=head1 SEE ALSO


VOCP, VOCP::Message, VOCP::Util

http://VOCPsystem.com

=cut




1;

__END__

