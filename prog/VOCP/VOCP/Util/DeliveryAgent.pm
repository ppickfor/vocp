package VOCP::Util::DeliveryAgent;

use VOCP;
use VOCP::Util;
use VOCP::Vars;
use FileHandle;


use strict;

use vars qw {
	$DefaultTempDir
	$TempDir
	$VERSION 
};

$VERSION = $VOCP::Vars::VERSION;
$DefaultTempDir = '/tmp';

$TempDir = $DefaultTempDir;

=head1 NAME

VOCP::Util::DeliveryAgent - delivers messages in various formats (sound files, txt) to VOCP boxes.

=head1 AUTHOR

LICENSE

    VOCP::Util::DeliveryAgent module, part of the VOCP voice messaging system package.
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

A typical call might be:

 
my $options = {
		'genconfig'	=> '/etc/vocp/vocp.conf',
		'boxconfig'	=> '/etc/vocp/boxes.conf',
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1,
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck		
	};
	
my $deliveryAgent = VOCP::DeliveryAgent->new($options);

=cut
		


sub new {
	my $class = shift;
	my $options = shift;
	
	my $self = {};
        
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


sub genConfig {
	my $self = shift;
	my $file = shift;
	
	if (defined $file)
	{
		$self->{'genconfig'} = $file;
	}
	
	return $self->{'genconfig'};
	
}

sub boxConfig {
	my $self = shift;
	my $file = shift;
	
	if (defined $file)
	{
		$self->{'boxconfig'} = $file;
	}
	
	return $self->{'boxconfig'};
	
}

sub _getVOCP {
	my $self = shift;
	
	return $self->{'vocp'} if ($self->{'vocp'});
	
	my $options = {
			'genconfig' => $self->genConfig(),
			'boxconfig' => $self->boxConfig(),
			'voice_device_type'	=> 'none',
			'nocalllog'	=> 1,
			'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck		
		};
	
	$self->{'vocp'} =  VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP object");
		
	return $self->{'vocp'};
}




=head2 deliverData DESTINATIONBOXNUMBER DATA DATATYPE

Will deliver DATA (converted if appropriate from DATATYPE to an acceptable box message format) to box number
DESTINATIONBOXNUMBER.

Will generate an error unless many conditions are met (file must exist, be of correct format or convertable,
box must exist and be a mail box, caller must be running as owner of the box or as root user, etc.).

=cut
		

sub deliverData {
	my $self = shift;
	my $destinations = shift;
	my $data = shift || VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): must pass some data in.") ;
	my $dataType = shift || VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): must specify data format.") ;
	my %messageMetaInfo = @_;

	my $vocp = $self->_getVOCP();
	
	my @destinationBoxList;
	my @destinationMailList;
	
	
	my @deliveredMessages;
	if (ref $destinations eq 'ARRAY')
	{
		foreach my $dest (@{$destinations})
		{
			if ($dest =~ /^\d+$/)
			{
				my $boxdetails = $vocp->get_box_details($dest)
					|| return 
					VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): No box '$dest' available");
				
				return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Box '$dest' is not a mail box")
					unless ($boxdetails->{'type'} eq 'mail');
				
				push @destinationBoxList, $dest;
			} else {
				push @destinationMailList, $dest;
			}
	
			
		}
	} else {
		if ($destinations =~ /^\d+$/)
		{
			$destinationBoxList[0] = $destinations;
		} else {
			$destinationMailList[0] = $destinations;
		}
	}
	
	
	
	my $voiceDevice = $vocp->voicedevice();
	
	my $validDataFormats = $voiceDevice->validDataFormats();
	
	
	VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): No valid formats found for voice device")
		unless (scalar @{$validDataFormats});
	
	my $validFormatRegex = join("|", @{$validDataFormats});
	
	
	# Not valid format, not pvf data - convert
	my $tmpDir = $TempDir || $vocp->{'tempdir'} || $DefaultTempDir ;
	
	my $baseTempName = "$tmpDir/vocpdeliv$$";
		
	
	my ($validData, $pvfFile, $outputFileName, $outputFileHandle);
	if ($dataType =~ m/^$validFormatRegex$/)
	{
		# Valid format - accept as-is
		$validData = $data;
	} elsif ($dataType eq 'pvf') {
		
		my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseTempName);
		
		return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Problem creating a tempfile based on '$baseTempName'")
			unless ($tmpFileHandle && $tmpFileName) ;
		
		$tmpFileHandle->autoflush();
		
		$tmpFileHandle->print($data);
		
		$pvfFile = $tmpFileName;
	} else {
	
		# Not valid format, not pvf data - convert
		my $baseTempName = "$tmpDir/vocpdeliv$$";
		
		my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseTempName);
		
		return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Problem creating a tempfile based on '$baseTempName'")
			unless ($tmpFileHandle && $tmpFileName) ;
		
		
		$tmpFileHandle->autoflush();
		
		$tmpFileHandle->print($data);
		
		my ($pvfFh, $pvfFileName) = VOCP::Util::safeTempFile($baseTempName);
		unless ($pvfFh && $pvfFileName)  {
			unlink $tmpFileName;
			$tmpFileHandle->close();
			
			return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Problem creating a tempfile based on '$baseTempName'");
		}
		
		unlink $pvfFileName;
		$pvfFh->close();
		my ($error, $message) = $vocp->X2pvf($tmpFileName, $pvfFileName, $dataType, 'NOOVERWRITE');
		
		unlink $tmpFileName;
		$tmpFileHandle->close();
		if ($error)
		{
			return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Encountered an error converting to PVF: $message");
		}
		
		$pvfFile = $pvfFileName;
	} 
	
	
	# Deliver the data to each voicemail box
	foreach my $dest (@destinationBoxList)
	{
	
		my $box = $vocp->get_box_object($dest);
	
		my $owner = $box->owner();
	
		# Getting user info from passwd file
		my ($name,$passwd,$owneruid,$ownergid,$quota,$comment,
			$gcos,$dir,$shell,$expire) = getpwnam($owner);
	
	
		unless ($> == 0 || $< == 0 || $> == $owneruid || $< == $owneruid)
		{
			VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): only the root user may deliver to boxes owned by another user.");
		}
		
		
		($outputFileHandle, $outputFileName) = $box->createNewMessageFileHandle();
		
		unless ($outputFileHandle && $outputFileName)
		{
			return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Could not create a new message file handle/name.");
		}
		
		if ($validData)
		{
			$outputFileHandle->autoflush();
			
			$outputFileHandle->print($validData);
			$outputFileHandle->close();
			push @deliveredMessages, $outputFileName;
		
		} elsif ($pvfFile) {
				
			
			my $format = $validDataFormats->[0];
			
			unlink $outputFileName;
			$outputFileHandle->close();
			
			my ($error, $message) = $vocp->pvf2X($pvfFile, $outputFileName, $format, undef, 'NOOVERWRITE');
			# unlink $pvfFile;
			if ($error)
			{
				return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Error converting pvf to $format - $message");
			}
			
			push @deliveredMessages, $outputFileName;
			
			
			
		} else {
		
			return VOCP::Util::error("VOCP::DeliveryAgent::deliverData(): Error no valid data and no pvf data found.");
		}
		
		my $boxMetaData = $box->metaData();
		
		
		my $deliveredMsgNum = $box->getLastMessageNumber();
		
		my $messageMetaData = $boxMetaData->messageData($deliveredMsgNum);
		
		while (my ($key, $val) = each %messageMetaInfo)
		{
			next if ($key =~ m|^_|);
			$messageMetaData->attrib($key, $val);
		}
		
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                      $atime,$mtime,$ctime,$blksize,$blocks) = stat($outputFileName);
		
		my $time = $mtime || $ctime || $atime || time();
		$messageMetaData->attrib('time', $time);
		$messageMetaData->attrib('size', $size);
		
		$boxMetaData->save();
		
		if ($owner) {
		
			my $metaDataFileName = $boxMetaData->getFileName();
			
			if ($name eq $owner && ($owneruid == $> || $owneruid == $< || $> == 0 || $< == 0))
			{
				VOCP::Util::log_msg("Changing ownership of file to $owner")
					if ($main::Debug > 1);
		
				# We use owner's uid or this processes, if unavailable
				my $uid = (defined $owneruid ? $owneruid : $>);
				# We get the group id.  
				# If the 'group' option is used in the conf file, we wish to 
				# set all files readable by this group (usefull for vocpweb)
				my $gid = $vocp->{'groupgid'} || $ownergid ;
				
				
				# Actually make the ownership/mode changes
				chown $uid, $gid, $outputFileName, $metaDataFileName;
				
				
			}
			
			
			# Set the mode according to the group option:
			# if group set in conf, set readable by group
			# else only readable by owner	
			my $mode = (defined $vocp->{'groupgid'} ? '0640' : '0600');
			chmod oct($mode), $outputFileName,$metaDataFileName ;	
			
			
		} # end if box has an owner
		
	} # end loop over each destination box
	
	
	
	#### TODO: Not implemented yet
	if (scalar @destinationMailList)
	{
	
		# Create the attachement
		# my $attachment = VOCP::Util::rmd2attachment()
		if ($validData && ! ($pvfFile))
		{
			# Make a pvf file
			
		}
		
		
		
		
		# send it to each
		foreach my $mailDest (@destinationMailList)
		{
			
			VOCP::Util::log_msg("VOCP::DeliveryAgent - delivery requested to '$mailDest' but not implemented yet!");
			
			
		} # end loop over each email recipient
		
	} # end if there are emails to send
	
	unlink $pvfFile if ($pvfFile);
	
	return \@deliveredMessages;
	
}
	

=head2 deliverFile DESTINATIONBOXNUMBER FILE FILETYPE

Will deliver FILE (converted if appropriate from FILETYPE to an acceptable box message format) to box number
DESTINATIONBOXNUMBER.

Will generate an error unless many conditions are met (file must exist, be of correct format or convertable,
box must exist and be a mail box, caller must be running as owner of the box or as root user, etc.).

=cut
		
sub deliverFile {
	my $self = shift;
	my $destinationBoxes = shift;
	my $mailFile = shift;
	my $fileType = shift;
	my %extraInfo = @_;
	
	unless (-e $mailFile && -r $mailFile)
	{ 
		VOCP::Util::error("DeliveryAgent::deliverFile(): can't find or cannot read file '$mailFile'");
	}
	
	my $inputFd = FileHandle->new();
	
	if (! $inputFd->open("<$mailFile"))
	{
		VOCP::Util::error("DeliveryAgent::deliverFile(): Could not open '$mailFile' for read: $!");
	}
	
	my $data = join('', $inputFd->getlines());
	
	$inputFd->close();
	
	return $self->deliverData($destinationBoxes, $data, $fileType, %extraInfo);
	
	
}

