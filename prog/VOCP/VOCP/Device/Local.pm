package VOCP::Device::Local;


use base qw (VOCP::Device);
use VOCP::Util;
use VOCP::Vars;
use VOCP::PipeHandle;
use VOCP::Util::DeliveryAgent;
use File::Copy;
use Audio::DSP;
use FileHandle;
use Fcntl;


=head1 NAME

VOCP::Device::Local - Uses /dev/dsp for local in/output.

=head1 AUTHOR

LICENSE

    VOCP::Device::Local module, part of the VOCP voice messaging system package.
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
		$UseAudioInit
		%AudioInit
		%SoundFiles
		$SoundFileDir
		$Rmd2LinCommand
		$DefaultRecordLength
		%GlobalFlags
		$DeviceDefined
		$VERSION
	};

$VERSION = $VOCP::Vars::VERSION;
$DeviceDefined = 1;

$Rmd2LinCommand = "rmdtopvf _RMDFILENAME_ | pvftolin";

# If you set $UseAudioInit to a TRUE value (eg 1), you need to make sure the AudioInit hash
# below has correct values (see the Audio::DSP perldoc for details)
$UseAudioInit = 0;


%AudioInit = (
			'device'	=> '/dev/dsp',
			'buffer'	=> 4096,
			'channels'	=> 1,
			'rate'		=> 8000,
			# format   => AFMT_U8,
		);

$SoundFileDir = $VOCP::Vars::VocpLocalDir . '/sounds';

%SoundFiles = (
		'click'	=> "$SoundFileDir/click.lin",
		'woosh'	=> "$SoundFileDir/woosh.lin",
		'tick'	=> "$SoundFileDir/tick.lin",
		'beep'	=> "$SoundFileDir/beep.lin",
	);


$DefaultRecordLength = 10;

sub connect {
	my $self = shift;
	my $params = shift;
	
	my %initParams = (
				'buffer'	=> $params->{'buffer'} || $self->{'buffer'} || $AudioInit{'buffer'},
				'channels'	=> $params->{'channels'} || $self->{'channels'} || $AudioInit{'channels'},
				'rate'		=> $params->{'rate'} || $self->{'rate'} || $AudioInit{'rate'},
				'device'	=> $params->{'device'} || $self->{'device'} || $AudioInit{'device'},
		);
	
	$self->{'DSP'} = new Audio::DSP(%initParams);
	if ($self->{'useaudioinit'} || $params->{'useaudioinit'} || $UseAudioInit)
	{
		$self->{'DSP'}->init() || VOCP::Util::error( $self->{'DSP'}->errstr());
	} else {
		$self->{'DSP'}->open(O_WRONLY) || VOCP::Util::error($self->{'DSP'}->errstr());
	}
	
	$self->{'initParams'} = \%initParams;
	$self->{'bytesPerSecond'} = $initParams{'channels'} * $initParams{'rate'}; # Guesstimate (depends on format)
	$self->{'recordlength'} ||= $params->{'recordlength'} || $DefaultRecordLength;
	$self->{'pvftooldir'} ||= $params->{'pvftooldir'} || $VOCP::Vars::Defaults{'pvftooldir'};
	 
	$GlobalFlags{$$}{'stop'} = 0;
	return 1;
}


sub disconnect {
	my $self = shift;
	my $params = shift;
	return 0 unless ($self->{'DSP'});

	$self->{'DSP'}->close();
	
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
	
	$self->blockingPlay($SoundFiles{'beep'});
	
	return 1;
}



=head2 dial DESTINATION

Connects to destination.  Returns defined & true on success.

=cut

sub dial {
	my $self = shift;
	my $destination = shift;
	
	VOCP::Util::log_msg("Called DIAL on 'Local' device ($destination) - ignoring.");
	
	return 1;
	
}


=head2 play PLAYPARAM

plays a sound (file, text-to-speech, whatever is appropriate) base on PLAYPARAM.  May or may not block during
play depending on device implementation.  Returns true on success.

=cut

sub play {
	my $self = shift;
	my $msg = shift;
	my $type = shift || 'rmd';
	my $blocking = shift;
	
	if ($msg) {
		VOCP::Util::error("VOCP::Device::Local::play really needs absolute paths ($msg)", $VOCP::Vars::Exit{'MISSING'})
			unless ($msg =~ m|^/|);
	} else {
		VOCP::Util::error("Pass a file to VOCP::Device::Local::play!", $VOCP::Vars::Exit{'MISSING'});
	}
	
	# Make sure we can read the msg
	VOCP::Util::error("$msg either does not exist or is unreadable", $VOCP::Vars::Exit{'FILE'})
		unless (-r $msg);
	
	VOCP::Util::log_msg("Playing message '$msg'")
		if ($main::Debug);
		
	$self->{'DSP'}->clear();
	
	$GlobalFlags{$$}{'stop'} = 0;
		
	my ($tmpFileHandle, $tmpFileName) ;
	if ($type eq 'lin' || $msg =~ m|\.lin$|)
	{
		$self->{'DSP'}->audiofile($msg);
		
	} elsif ($type eq 'rmd' || $msg =~ m|\.rmd$|) {
		# Assume it is an RMD file...
		
		my $syscall = $Rmd2LinCommand;
		$syscall =~ s/_RMDFILENAME_/$msg/g;
		
		my $baseName = $VOCP::Vars::Defaults{'tempdir'} . "/vocpldev$$";
		
		($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseName);
		
		unless ($tmpFileHandle && $tmpFileName)
		{
			VOCP::Util::error("VOCP::Device::Local::play() Could not create a tempfile based on '$baseName'");
		}
		
		my $rmdToLinFd = VOCP::PipeHandle->new();
		if (! $rmdToLinFd->open("$syscall |"))
		{
			VOCP::Util::error("VOCP::Device::Local::play() Could not open '$syscall' for read $!");
		}
		
		$tmpFileHandle->autoflush();
		
		while (my $inputline = $rmdToLinFd->getline())
		{
			$tmpFileHandle->print($inputline);
		}
		$rmdToLinFd->close();
		
		$self->{'DSP'}->audiofile($tmpFileName);
	} else {
		VOCP::Util::error("VOCP::Device::Local::play() Unknown file type '$type'");
	}
	
	
	while ($self->{'DSP'}->write() && ! $GlobalFlags{$$}{'stop'}) {
		$self->{'DSP'}->sync() if ($blocking);
		print STDERR "Datalen = " . $self->{'DSP'}->datalen() . "\n" if ($main::Debug);
	}
	
	if ($GlobalFlags{$$}{'stop'})
	{
		
		$self->stop();
		$GlobalFlags{$$}{'stop'} = 0;
	}
	
	
	if ($tmpFileName)
	{
		unlink ($tmpFileName);
		$tmpFileHandle->close();
	}
	
	return 1;
	
}





=head2 record TOFILE

Records input from user to device to file TOFILE.  Returns true on success.

=cut

sub record {
	my $self = shift;
	my $tofile = shift;
	my $type = shift || 'lin';
	
	VOCP::Util::error("Must pass a filename to VOCP::Device::Local::record()") 
		unless ($tofile);
	
	if (-e $tofile)
	{
		VOCP::Util::error("VOCP::Device::Local::record() File '$tofile' already exists");
	} 
	
	
	my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($tofile);
	unless ($tmpFileHandle && $tmpFileName)
	{
		VOCP::Util::error("VOCP::Device::Local::record() Could not create a tempfile based on '$tofile'");
	}
	
	
	$self->{'DSP'}->clear();
	
	my $length = $self->{'recordlength'} * $self->{'bytesPerSecond'} || 40000;
	my $buf = $self->{'initParams'}->{'buffer'} || 4096;
	for (my $i = 0; $i <= $length; $i+=$buf)
	{
		##### TODO - the read here fails??
		#$self->{'DSP'}->read() || VOCP::Util::error("VOCP::Device::Local::record() error: " . $self->{'DSP'}->errstr());
	}
	$tmpFileHandle->autoflush();
	
	######### TODO - problem with the read above causes pain here:
	#$tmpFileHandle->print($self->{'DSP'}->data());
	$tmpFileHandle->print("\000" x 800);
	if ($type eq 'lin')
	{
		if (-e $tofile)
		{
			unlink $tmpFileName;
			$tmpFileHandle->close();
			VOCP::Util::error("VOCP::Device::Local::record() File '$tofile' already exists");
		}
		
		if (copy($tmpFileName, $tofile))
		{
			VOCP::Util::log_msg("VOCP::Device::Local::record() Copying $tmpFileName to $tofile")
				if ($main::Debug);
		} else {
			VOCP::Util::error("VOCP::Device::Local::record() Could not copy $tmpFileName to $tofile");
		}
		unlink $tmpFileName;
		$tmpFileHandle->close();
	} elsif ($type eq 'rmd')
	{
		VOCP::Util::log_msg("VOCP::Device::Local::record(): rmd file type not supported yet.");
	} else {
		VOCP::Util::error("VOCP::Device::Local::record() Record type '$type' unknown!");
	}
	
	return 1;
}


=head2 wait TIME

Simply waits for TIME seconds.  Device should accept/queue user input 
during interval.

=cut

sub wait {
	my $self = shift;
	my $time = shift;
	
	sleep($time);
	
	return 1;
}


=head2 waitFor STATE

Waits until STATE is reached/returned by device.  Device should accept/queue user input 
during interval.

=cut

sub waitFor {
	my $self = shift;
	my $state = shift;
	
	return 1;

}


=head2 stop

Immediately stop any current activity (wait, play, record, etc.).

=cut
sub stop {
	my $self = shift;
	
	$GlobalFlags{$$}{'stop'} = 1;
	$self->{'DSP'}->clear();
	$self->{'DSP'}->reset();
}

=head2 blocking_play PLAYTHIS

play PLAYTHIS and return only when done.

=cut

sub blockingPlay {
	my $self = shift;
	my $playthis = shift;
	my $type = shift;
	
	$self->play($playthis, $type, 'BLOCKING');
	
	
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
	my $repeatTimes = shift || $self->{'numrepeat'} || 3;
	
	unless (defined $timeout)
	{
		$timeout = $self->{'timeout'} || 6;
	}
	
	if ($playthis)
	{
		$self->play($playthis);
	}
	
	if ($timeout == 0)
	{
		return '';
	}
	
	my $retnum = 1;
	if ($self->{'readnumcallback'})
	{
		$retnum = &{$self->{'readnumcallback'}};
	}
		
	$self->stop();
	
	return $retnum;
}

=head2 validDataFormats 

Returns an array ref of valid data formats (eg 'rmd', 'wav', 'au') the device will accept.

=cut

sub validDataFormats {
	my $self = shift;
	
	my @validFormats = ('lin', 'rmd');
	
	return \@validFormats;
}


sub receiveImage {
	my $self = shift;
	
	print STDERR "VOCP::Device::Local::receiveImage() Called - impossible on this interface, exiting\n";
	
	exit(2);
	
}


# Not sure what to do with this method... how do you support faxes while abstracting the modem voice device??
sub sendImage {
	my $self = shift;
	my $file = shift;
	
	print STDERR "VOCP::Device::Local::sendImage() Called - impossible on this interface, exiting\n";
	
	exit(2);
}



=head1 AUTHOR

LICENSE

    VOCP::Device::Local module, part of the VOCP voice messaging system package.
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
