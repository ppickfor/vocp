package VOCP::Device::None;


use base qw (VOCP::Device);

use VOCP::Vars;

use strict;

use vars qw {
		$DeviceDefined
		$VERSION
	};

$VERSION = $VOCP::Vars::VERSION;
$DeviceDefined = 1;

=head1 VOCP::Device::None

=head1 NAME

	VOCP::Device::None - Used when no voice device is required (eg box configuration program)


=head1 SYNOPSIS

This "device" is to be used in cases when we wish to acces VOCP functionality, by instantiating a
VOCP object, but have no need for any actual voice device (like the VOCP::Device::Vgetty or VOCP::Device::Local
devices).  VOCP::Device::None inherits from VOCP::Device and provides the same interface - it just doesn't actually
do anything ;)


=head1 AUTHOR

LICENSE

    VOCP::Device::None module, part of the VOCP voice messaging system package.
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


sub init {
	my $self = shift;
	my $params = shift;

	return 1;
	
}


sub connect {
	my $self = shift;
	my $params = shift;
	
	return 1;
}


sub disconnect {
	my $self = shift;
	my $params = shift;
	
	return 1;
}



sub beep {
	my $self = shift;
	my $frequency = shift;
	my $length = shift;
	
	return 1;
}


sub dial {
	my $self = shift;
	my $destination = shift;
	
	return 1;
}

sub play {
	my $self = shift;
	my $playthis = shift;
	my $type = shift;
	
	return 1;
}


sub record {
	my $self = shift;
	my $tofile = shift;
	
	return 1;
}


sub wait {
	my $self = shift;
	my $time = shift;
	
	return 1;
}


sub waitFor {
	my $self = shift;
	my $state = shift;
	
	return 1;
}

sub stop {
	my $self = shift;
	
	return 1;
}


sub blockingPlay {
	my $self = shift;
	my $playthis = shift;
	my $type = shift;
	
	return 1;
}


sub inputMode {
	my $self = shift;
	my $setTo = shift;
	
	if (defined $setTo)
	{
		$self->{'inputmode'} = $setTo;
	}
	
	return $self->{'inputmode'};
}



sub readnum {
	my $self = shift;
	my $playthis = shift;
	my $timeout = shift;
	my $repeatTimes = shift || 3;
	
	return 1;
}



sub validDataFormats {
	my $self = shift;
	
	return ['rmd'];
}


# Not sure what to do with this method... how do you support faxes while abstracting the modem voice device??
sub sendImage {
	my $self = shift;
	my $file = shift;
	
	return 1;
}


=head1 AUTHOR

LICENSE

    VOCP::Device::None module, part of the VOCP voice messaging system package.
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

