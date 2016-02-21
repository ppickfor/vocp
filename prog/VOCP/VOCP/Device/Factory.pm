package VOCP::Device::Factory;


use VOCP::Util;
use VOCP::Vars;

use strict;

use vars qw{
		$ValidDevices
		$VERSION
	};
	
$VERSION = $VOCP::Vars::VERSION;
$ValidDevices = join('|', @VOCP::Vars::ValidDevices);


=head1 NAME

VOCP::Device::Factory - Used to encapsulate VOCP::Device subclass instantiation

=head1 AUTHOR

LICENSE

    VOCP::Device::Factory module, part of the VOCP voice messaging system package.
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
	
	$self->init($params) if ($params);
	
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

=head2 newDevice %PARAMS

Create and return a new VOCP::Device of type $PARAMS{'type'}, passing
\%PARAMS to constructor.

=cut

sub newDevice {
	my $self = shift;
	my %params = @_;
	
	return VOCP::Util::error("Must pass a device type parameter to VOCP::Device::Factory::newDevice")
		unless (defined $params{'type'});
		
	return VOCP::Util::error("VOCP::Device::Factory::newDevice() Unrecognized device type " . $params{'type'})
		unless ($params{'type'} =~ /^$ValidDevices$/);
	
	if ($params{'type'} eq 'vgetty')
	{
		require VOCP::Device::Vgetty unless (defined $VOCP::Device::Vgetty::DeviceDefined);
		return VOCP::Device::Vgetty->new(\%params);
	} elsif ($params{'type'} eq 'vgettyold')
	{
		require VOCP::Device::VgettyOld unless (defined $VOCP::Device::VgettyOld::DeviceDefined);
		return VOCP::Device::VgettyOld->new(\%params);
	} elsif ($params{'type'} eq 'local')
	{
		require VOCP::Device::Local unless (defined $VOCP::Device::Local::DeviceDefined);
		return VOCP::Device::Local->new(\%params);
	} elsif ($params{'type'} eq 'none')
	{
		require VOCP::Device::None unless (defined $VOCP::Device::None::DeviceDefined);
		return VOCP::Device::None->new(\%params);
	}
	
	return undef;
}
		
	
	
