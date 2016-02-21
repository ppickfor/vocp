package VOCP::Device;

use VOCP::Util;
use VOCP::Vars;


use strict;
use vars qw {
		$DeviceDefined
		%InputMode
		$VERSION 
	};

$VERSION = $VOCP::Vars::VERSION;
$DeviceDefined = 1;
%InputMode = (
		'FIXEDDIGIT'	=> 1,
		'MULTIDIGIT'	=> 2,
	);

=head1 VOCP::Device

=head1 NAME

	VOCP::Device - Encapsulates the communications device (eg Voice Modem)


=head1 SYNOPSIS

The VOCP::Device module is meant to serve as an abstract base
class for voice communication devices.  
	
It provides the interface VOCP::Device::XXX modules are expected
to implement.

=head1 AUTHOR

LICENSE

    VOCP::Device module, part of the VOCP voice messaging system package.
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


=head2 new [PARAMHREF]

Creates a new instance, calling init() with PARAMHREF if passed.
Returns a new blessed object.

=cut

sub new {
	my $class = shift;
	my $params = shift;
	
	my $self = {};
        
        bless $self, ref $class || $class;
	
	
	$self->{'autostop'} = (defined $params->{'autostop'}) ? $params->{'autostop'} : $VOCP::Vars::Defaults{'autostop'};
	
	$self->{'timeout'} = (defined $params->{'timeout'}) ?  $params->{'timeout'} : $VOCP::Vars::Defaults{'timeout'};
	
	$self->{'numrepeat'} = (defined $params->{'numrepeat'}) ?  $params->{'numrepeat'} : $VOCP::Vars::Defaults{'numrepeat'};
	
	$self->{'device'} = (defined $params->{'device'}) ? $params->{'device'} : $VOCP::Vars::Defaults{'device'};
	
	$self->{'inputmode'} = (defined $params->{'inputmode'}) ? $params->{'inputmode'} : $InputMode{'FIXEDDIGIT'};
	
	while (my ($key, $val) = each %{$params})
	{
		$self->{$key} = $val;
	}

	
	$self->init($params);
		
	
	return $self;
}


=head2 init PARAMHREF

Called by new(). This method is used in derived classes to perform startup initialisation.
Override this method if required.

=cut

sub init {
	my $self = shift;
	my $params = shift;
	
	
	
	return 1;
	
}


=head1 Subclass method stubs

The following methods are in this parent class (but only implemented as stubs) in order to define a
common interface for all VOCP::Device subclasses.

These methods are actually heavily based on the Modem::Vgetty package methods and the interface should
be considered tentative and expected to change as new devices are added (eg a SIP voice over IP interface
would be nice).

=cut


sub connect {
	my $self = shift;
	my $params = shift;
	
	print STDERR "VOCP::Device::connect() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}


sub disconnect {
	my $self = shift;
	my $params = shift;
	
	print STDERR "VOCP::Device::connect() Call to parent class stub - please implement in subclass.\n";
	
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
	
	print STDERR "VOCP::Device::beep() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}



=head2 dial DESTINATION

Connects to destination.  Returns defined & true on success.

=cut

sub dial {
	my $self = shift;
	my $destination = shift;
	
	print STDERR "VOCP::Device::dial() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}


=head2 play PLAYPARAM

plays a sound (file, text-to-speech, whatever is appropriate) base on PLAYPARAM.  May or may not block during
play depending on device implementation.  Returns true on success.

=cut

sub play {
	my $self = shift;
	my $playthis = shift;
	my $type = shift;
	
	
	print STDERR "VOCP::Device::play() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}


=head2 record TOFILE

Records input from user to device to file TOFILE.  Returns true on success.

=cut

sub record {
	my $self = shift;
	my $tofile = shift;
	
	
	print STDERR "VOCP::Device::record() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}


=head2 wait TIME

Simply waits for TIME seconds.  Device should accept/queue user input 
during interval.

=cut

sub wait {
	my $self = shift;
	my $time = shift;
	
	
	print STDERR "VOCP::Device::wait() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}


=head2 waitFor STATE

Waits until STATE is reached/returned by device.  Device should accept/queue user input 
during interval.

=cut

sub waitFor {
	my $self = shift;
	my $state = shift;
	
	print STDERR "VOCP::Device::waitFor() Call to parent class stub - please implement in subclass.\n";
	
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
	my $playthis = shift;
	my $type = shift;
	
	
	print STDERR "VOCP::Device::blocking_play() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}


=head2 inputMode [MODE]

Returns the current input mode (single- or multi- digit currently supported), optionally setting to 
MODE, if passed - use the %VOCP::Device::InputMode hash for valid MODE values.

=cut

sub inputMode {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{
		$self->{'inputmode'} = $setTo;
	}
	
	return $self->{'inputmode'};
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


=head2 validDataFormats 

Returns an array ref of valid data formats (eg 'rmd', 'wav', 'au') the device will accept.

=cut

sub validDataFormats {
	my $self = shift;
	
	print STDERR "VOCP::Device::validDataFormats() Call to parent class stub - please implement in subclass.\n";
	
	return undef;
}



sub receiveImage {
	my $self = shift;
	
	print STDERR "VOCP::Device::receiveImage() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}


# Not sure what to do with this method... how do you support faxes while abstracting the modem voice device??
sub sendImage {
	my $self = shift;
	my $file = shift;
	
	print STDERR "VOCP::Device::sendImage() Call to parent class stub - please implement in subclass.\n";
	
	return 1;
}



=head1 SEE ALSO


VOCP, VOCP::Message, VOCP::Util

http://VOCPsystem.com

=cut




1;

__END__

