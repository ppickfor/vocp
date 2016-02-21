package VOCP::Box::MetaData;

use VOCP::Util;
use VOCP::Vars;
use XML::Mini;


use strict;


=head1 VOCP::Box::MetaData


=head2 NAME

VOCP::Box::MetaData - Represents data about a box and it's contents.

=head2 SYNOPSIS

Normally, the MetaData is accessed through the VOCP::Box or VOCP::Message objects
but it can also be used directly as demonstrated below.

	use VOCP::Box::MetaData;
	
	my $boxNumber = 100;
	my $initParams = {
				'inboxdir'	=> '/full/path/to/inbox',
			};
			
	my $boxData = VOCP::Box::MetaData->new(100, $initParams);
	
	my $msgData = $boxData->messageData('0006');
	
	$msgData->flag('read', 1);
	
	$boxData->save();
	

	# later
	
	my $boxData = VOCP::Box::MetaData->new(100, $initParams);
	
	
	my $messages = $boxData->allMessageData();
	my ($unreadCount, $urgent$Count);
	foreach my $msgData (@{$messages})
	{
		my $type = $msgData->attrib('source');
		
		next unless ($type eq 'phone');
		
		print "Message " . $msgData->id() . " is a telephone message.\n";
		
		$unreadCount++ if ($msgData->flag('read'));
		$urgentCount++ if ($msgData->flag('urgent'));
	}
	
	print "$unreadCount unread and $urgentCount urgen phone messages\n";



=head1 AUTHOR

LICENSE

    VOCP::Box::MetaData module, part of the VOCP voice messaging system package.
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
		$UnaryFlag
		$VERSION
	};

$VERSION = $VOCP::Vars::VERSION;
$UnaryFlag = '_UNARYFLAG';


sub new {
	my $class = shift;
	my $boxNumber = shift || VOCP::Util::error("Must pass a BOX number to Box::MetaData::new()"); 	
	my $params = shift;
	

	# Create href and set up defaults
	my $self = {
			'inboxdir'	=> $VOCP::Vars::Defaults{'inboxdir'},
		};
        
        bless $self, ref $class || $class;
	
	while (my ($key, $val) = each %{$params})
	{
		$self->{$key} = $val;
	}
	
	$self->inboxDir($self->{'inboxdir'}) if ($self->{'inboxdir'});
	$self->boxNumber($boxNumber);
	
	my $filename = $self->getFileName();
	
	
	if (-e $filename)
	{
		$self->fromFile($filename);
	}

	return $self;
}


sub inboxDir {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{
		VOCP::Util::error("Box::MetaData::inboxDir() Directory '$setTo' must be FULL path.")
			unless ($setTo =~ m|^(/.+)$|);
		
		$setTo = $1; # Cheap untaint but we will check it further
		
		VOCP::Util::error("Box::MetaData::inboxDir() Directory '$setTo' looks weird - aborting.")
			if ($setTo =~ m|/\.\./| || $setTo =~ m/[\*;`#\s]+/);
		
		VOCP::Util::error("Box::MetaData::inboxDir() Directory '$setTo' doesn't seem to exist.")
			unless (-e $setTo);
		
		$setTo .= '/' unless ($setTo =~ m|/$|);
		
		$self->{'inboxdir'} = $setTo;
		
	}
	
	return $self->{'inboxdir'};
}

sub boxNumber {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{
		VOCP::Util::error("Box::MetaData::boxNumber() Trying to set boxNumber to non-numeric value '$setTo'.")
			unless ($setTo =~ m|^(\d+)$|);
		
		$self->{'boxnumber'} = $1; # untaint
	}
	
	return $self->{'boxnumber'};
}

sub getFileName {
	my $self = shift;
	
	my $filename = $self->inboxDir() . '.flag.' . $self->boxNumber();
	
	return $filename;
}


sub messageData {
	my $self = shift;
	my $id = shift ;
	
	unless (defined $id)
	{
		return VOCP::Util::error("VOCP::Box::MetaData::messageData - must pass message ID");
	}
	
	unless ($self->{'boxData'}->{'messages'}->{$id})
	{
		
		$self->{'boxData'}->{'messages'}->{$id} = VOCP::Box::MetaData::Message->new($id)
			|| VOCP::Util::error("VOCP::Box::MetaData::messageData could not create new VOCP::Box::MetaData::Message object");
	}
	
	return $self->{'boxData'}->{'messages'}->{$id};
}

sub deleteMessageData {
	my $self = shift;
	my $id = shift;
	
	unless (defined $id)
	{
		return VOCP::Util::error("VOCP::Box::MetaData::deleteMessageData - must pass message ID");
	}
	my $retVal = (defined $self->{'boxData'}->{'messages'}->{$id}) ? 1 : 0;
	
	delete $self->{'boxData'}->{'messages'}->{$id};
	
	return $retVal;
} 


sub fromFile {
	my $self = shift;
	my $filename = shift || $self->getFileName();
	
	VOCP::Util::error("Box::MetaData::fromFile() Must pass a FULL path filename ('$filename')")
		unless ($filename =~ m|^/|);
	
	VOCP::Util::error("Box::MetaData::fromFile() Trying to init but cannot read '$filename'")
		unless (-r $filename);  
		
		
	$self->{'xmlDoc'} = XML::Mini::Document->new() 
				|| VOCP::Util::error("Box::MetaData::fromFile() Could not create new XML::Mini document.");
		
	my $numChildren = $self->{'xmlDoc'}->fromFile($filename);

	if ($numChildren)
	{
		$self->parseXMLDoc($self->{'xmlDoc'});
	}	
	return $numChildren;
}


=head2


 
<?xml version="1.0" ?>
<VOCPMetaData>
<boxData>
 <message id="0005">
   <delivery>
     phone
   </delivery>
   <from>
     5145551212
   </from>
   <flags>
     <read />
     <flagged />
   </flags>
   <size>
    324235
   </size>
 </message>
 <message id="0006">
   <delivery>
     email
   </delivery>
   <from>
     &quot;Ralph Mouth&quot; &lt;ralph@happy.com&gt;
   </from>
 </message>
</boxData>
</VOCPMetaData>

=cut
     
sub parseXMLDoc {
	my $self = shift;
	my $xmlDoc = shift || $self->{'xmlDoc'} || VOCP::Util::error("Must pass an xml doc to Box::MetaData::parseXMLDoc()");
	
	my $xmlRoot = $xmlDoc->getRoot() 
		|| VOCP::Util::error("Box::MetaData::parseXMLDoc() Problem getting root element from XML::Mini::Document");
	
	
	$self->{'boxData'} = {};
	
	my $boxData = $xmlRoot->getElementByPath('VOCPMetaData/boxData');
	unless ($boxData)
	{
		VOCP::Util::log_msg("Box::MetaData::parseXMLDoc() No boxData element found in xmldoc");
		return undef;
	}
	
	my $boxChildren = $boxData->getAllChildren('message');
	
	my $numChildren = scalar @{$boxChildren};
	my $count = 0;
	for(my $i=0; $i<$numChildren; $i++)
	{
		my $msgnum = $boxChildren->[$i]->attribute('id');
		
		unless (defined $msgnum)
		{
			VOCP::Util::log_msg("Box::MetaData::parseXMLDoc() Got a message without an 'id' attrib - skipping.");
			next;
		}
		my $messageChildren = $boxChildren->[$i]->getAllChildren();
		my $initHash = {};
		foreach my $messageChild (@{$messageChildren})
		{
			my $name = $messageChild->name();
			next if ($name eq 'flags');
			$initHash->{$name} = $messageChild->getValue() ;
		}
		
		my $flags = $boxChildren->[$i]->getElement('flags');
		
		if ($flags)
		{
			my $flagChildren = $flags->getAllChildren();
			
			foreach my $flagElement (@{$flagChildren})
			{
				my $name = $flagElement->name();
				my $val = $flagElement->getValue() || $UnaryFlag;
				$initHash->{'flags'}->{$name} = $val;
			}
		}
		
		
		$self->{'boxData'}->{'messages'}->{$msgnum} = VOCP::Box::MetaData::Message->new($msgnum, $initHash)
				|| VOCP::Util::error("VOCP::Box::MetaData::parseXMLDoc() - could not create a "
							. "VOCP::Box::MetaData::Message for $msgnum");
		
		$count++;
		
	}
	
	return $count;
}



sub save {
	my $self = shift;
	my $file = shift || $self->getFileName(); # optionally specify
	
	VOCP::Util::error("Box::MetaData::save() Must specify a FULL path name for file to save ('$file')")
		unless ($file =~ m|^/|);
	
	my $dir = $file;
	$dir =~ s|(/.+/)[^/]+$|$1|;
	
	VOCP::Util::error("Box::MetaData::save() Trying to save to $file but director '$dir' does not seem to exist")
		unless (-e $dir && -d $dir);
	
	VOCP::Util::error("Box::MetaData::save() Trying to save to $file but no permission to write to $dir")
		unless (-w $dir);
	
	my $xmlDoc = XML::Mini::Document->new() 
				|| VOCP::Util::error("Box::MetaData::save() Could not create new XML::Mini document.");
	
	my $xmlRoot = $xmlDoc->getRoot();
	
	my $vocpmetatag = $xmlRoot->createChild('VOCPMetaData');
	
	my $boxData = $vocpmetatag->createChild('boxData');
	
	
	foreach my $msgnum (sort keys %{$self->{'boxData'}->{'messages'}})
	{
		
		next unless ($self->{'boxData'}->{'messages'}->{$msgnum});
		
		my $msgDataEl = $boxData->createChild('message');
		$msgDataEl->attribute('id', $msgnum);
		
		my $msgData = $self->{'boxData'}->{'messages'}->{$msgnum}->allAttributes();
		
		my $flagsEl;
		if ($msgData->{'flags'})
		{
			# Create an orphan 'flags' element - don't forget to append on end
			$flagsEl = $xmlDoc->createElement('flags');
			foreach my $flagName (sort keys %{$msgData->{'flags'}})
			{
				my $val = (defined $msgData->{'flags'}->{$flagName}) ? $msgData->{'flags'}->{$flagName} : $UnaryFlag;
				
				my $flagChild = $flagsEl->createChild($flagName);
				if ($val ne $UnaryFlag)
				{
					$flagChild->text($val);
				}
				
			} # end loop over message flags
			
			# Get rid of the data (so it isn't duplicated below)
			delete $msgData->{'flags'};
			
		} # end if 'flags' key set for message
		
		
		# Create XML for each data chunk assigned to this message
		while (my ($msgDKey, $msgDVal) = each %{$msgData})
		{
			my $mgdEl = $msgDataEl->createChild($msgDKey);
			$mgdEl->text($msgDVal) if (defined $msgDVal);
		}
		
		# Don't forget! Append the flags element & it's children
		$msgDataEl->appendChild($flagsEl) if ($flagsEl);
		
	} # End loop over each message
	
	
	#### Do some cleaning up
	my $messageElements = $boxData->getAllChildren('message');
	foreach my $msgEl (@{$messageElements})
	{
		my $numMsgChildren = $msgEl->numChildren();
		unless ($numMsgChildren)
		{
			# This message contains no data - may have been deleted
			$boxData->removeChild($msgEl);
		}
	}
	
	my $contentLength = $xmlDoc->toFile($file, 'SAFEWRITE');
	
	VOCP::Util::error("Box::MetaData::save() XML::Mini::Document::toFile returned 0 content written...")
		unless ($contentLength);

	return $contentLength;
	
					
}












#########################################################################################################
###################################   VOCP::Box::MetaData::Message   ####################################
#########################################################################################################


package VOCP::Box::MetaData::Message;

use strict;

sub new {
	my $class = shift;
	my $msgnum = shift || VOCP::Util::error("Must pass a message number to Box::MetaData::Message::new()"); 	
	my $params = shift;
	

	VOCP::Util::error("Box::MetaData::Message::new() message number must be numeric ('$msgnum')")
		unless ($msgnum =~ m|^(\d+)$|);
	
	$msgnum = $1; # untaint
	# Create href and set up defaults
	my $self = {
			'_id'	=> $msgnum,
		};
        
        bless $self, ref $class || $class;
	
	if ($params)
	{
		if ($params->{'flags'})
		{
			while (my ($flagname, $flagval) = each %{$params->{'flags'}})
			{
				$self->{'_flags'}->{$flagname} = $flagval;
			}
			
			delete $params->{'flags'};
		}
		
		while (my ($key, $val) = each %{$params})
		{
			$self->{$key} = $val;
		}
	}
	
	return $self;
}

sub id {
	my $self = shift;
	my $setTo = shift; # optional
	
	if (defined $setTo)
	{
		unless ($setTo =~ m|^(\d+)$|)
		{
			VOCP::Util::error("VOCP::Box::MetaData::Message::id() Can only set numeric ID ($setTo)");
		}
		
		$setTo = $1; # untaint
		
		$self->{'_id'} = $setTo;
	}
	
	return $self->{'_id'};
	
} 

sub attrib {
	my $self = shift;
	my $attrName = shift || VOCP::Util::error("Must pass an attribute name to Box::MetaData::Message::attrib()"); 	
	my $attrVal = shift;
	
	if (defined $attrVal)
	{
		$self->{$attrName} = $attrVal;
	}
	
	if (exists $self->{$attrName})
	{
		return $self->{$attrName};
	}
	
	return undef;
}



sub flag {
	my $self = shift;
	my $flagName = shift || VOCP::Util::error("Must pass an flag name to Box::MetaData::Message::flag()"); 
	my $value = shift; # optionally set
	
	if (defined $value)
	{
		if ($value)
		{
			$self->{'_flags'}->{$flagName} = $VOCP::Box::MetaData::UnaryFlag;
		} else {
			delete $self->{'_flags'}->{$flagName};
		}
	}
	
	my $ret = undef;
	
	if (exists $self->{'_flags'}->{$flagName} )
	{
		$ret = ($self->{'_flags'}->{$flagName} eq $$VOCP::Box::MetaData::UnaryFlag) ? 1 : $self->{'_flags'}->{$flagName} ;
	}
	
	return $ret;
}

sub allAttributes {
	my $self = shift;
	
	my $retval = {};
	
	while (my ($key, $val) = each %{$self})
	{
		next if ($key =~ m|^_|);
		$retval->{$key} = $val;
	}
	
	if (exists $self->{'_flags'})
	{
		while (my ($key, $val) = each %{$self->{'_flags'}})
		{
			$retval->{'flags'}->{$key} = $val;
		}
	}
	
	return $retval;
}



1;
		
		
