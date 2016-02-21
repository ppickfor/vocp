package VOCP::PipeHandle;
use VOCP::Vars;
use IO::Pipe;


use strict;
=head1 VOCP::PipeHandle

=head2 NAME

VOCP::PipeHandle - provides a FileHandle like interface to read or write pipes.

=head2 SYNOPSIS


 
	use VOCP::PipeHandle;
	use VOCP::Util;
	
	my $script = VOCP::PipeHandle->new();
	
	if (! $script->open("/path/to/program |"))
	{
		VOCP::Util::error("Could not open program for read $!");
	}
	
	while (my $outputLine = $script->getline())
	{
		# do stuff
	}
	
	# OR
	my $output = join('', $script->getlines());
	
	$script->close();
	
	
	# ...
	
	my $writeToScript = VOCP::PipeHandle->new();
	
	if (! $writeToScript->open("| /path/to/program"))
	{
		VOCP::Util::error("Could not open program for write $!");
	}
	
	$writeToScript->print("Some input for program...");
	
	$writeToScript->close();
	

=head2 DESCRIPTION

This module provides an interface (similar to FileHandle's) for the read or write pipes
used when launching and communicating with another program (through it's STDIN or STDOUT).

I think FileHandle could have been used instead, but this module will allow VOCP to 
eventually do some further sanity checks when launching programs (checking path, ownership
or whatever).

Please see FileHandle's perldoc for interface info.  Supported methods are:

new(), open(), getline(), getlines(), print(), close()


=head1 AUTHOR

LICENSE

    VOCP::PipeHandle module, part of the VOCP voice messaging system package.
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


=head1 SEE ALSO

http://VOCPsystem.com

=cut

use vars qw{

		$VERSION
};

$VERSION = $VOCP::Vars::VERSION;



sub new {
	my $class = shift;
	my $open = shift;
	
	my $self = {};
        
        bless $self, ref $class || $class;
	
	$self->{'pipe'} = new IO::Pipe;
	
	$self->open($open) if ($open);
	
	return $self;
}


sub open {
	my $self = shift;
	my $open = shift;
	
	if ($self->{'write'} || $self->{'read'})
	{
		return VOCP::Util::error("VOCP::PipeHandle::open() - Already opened!");
	}
	
	if ($open =~ /^\s*\|(.+)/)
	{
		my $openwrite = $1;
		$self->{'write'} = 1;
		return $self->{'pipe'}->writer($openwrite);
	} elsif ($open =~ /(.+)\s*\|\s*$/)
	{
		my $openread = $1;
		$self->{'read'} = 1;
		my $reader = $self->{'pipe'}->reader($openread);
		$self->{'_readbits'} = '';
		vec($self->{'_readbits'}, $reader->fileno(), 1) = 1;
		return $reader;
	}
	
	VOCP::Util::error("VOCP::PipeHandle::open() - '$open' is not a read or write pipe");
	
}

sub print {
	my $self = shift;
	my $input = shift;
	
	unless ($self->{'write'})
	{
		VOCP::Util::error("VOCP::PipeHandle not opened for write");
	}
	
	my $pipe = $self->{'pipe'} ;
	print $pipe $input;
	
}

sub poll {
	my $self = shift;
	my $timeout = shift || 0.1;
	
	unless ($self->{'read'})
	{
		VOCP::Util::error("VOCP::PipeHandle::poll() called but not open for read");
	}
	
	my $rbits;
	my $nfound = select($rbits = $self->{'_readbits'},undef,undef,$timeout); 
	
	return if ($nfound == 0);
	
	return 1;
}

sub getline {
	my $self = shift;
	
	unless ($self->{'read'})
	{
		VOCP::Util::error("VOCP::PipeHandle not opened for read");
	}
	
	my $pipe = $self->{'pipe'} ;
	my $line = <$pipe>;
	
	return $line;
}

sub getlines {
	my $self = shift;
	
	unless ($self->{'read'})
	{
		VOCP::Util::error("VOCP::PipeHandle not opened for read");
	}
	
	my $pipe = $self->{'pipe'} ;
	my @lines = <$pipe>;
	
	return @lines;
	
}

sub close {
	my $self = shift;
	unless ($self->{'read'} || $self->{'write'})
	{
		VOCP::Util::log_msg("VOCP::PipeHandle::close() not opened");
		return undef
	}
	
	my $ret;
	my $pipe = $self->{'pipe'} ;
	if ($pipe->opened())
	{
		my $oldReaper;
		if ($SIG{CHLD})
		{
			$oldReaper = $SIG{CHLD};
			$SIG{CHLD} = \&emptyReaper;
		}
		$ret = $pipe->close();
		$SIG{CHLD} = $oldReaper if ($oldReaper);
	} 
	delete $self->{'pipe'};
	delete $self->{'write'};
	delete $self->{'read'};
	
	return $ret;
	
}


sub emptyReaper {
	
	return;
}


sub autoflush {
	my $self = shift;
	
	#my $fd = $self->{'fd'};
	#my $oldfd = select ($fd);
	#$|=1;
	#select($oldfd);
}


sub DESTROY {
	my $self = shift;
	
	if ($self->{'pipe'})
	{
		my $pipe = $self->{'pipe'};
		$pipe->close();
		VOCP::Util::log_msg("VOCP::PipeHandle::DESTROY called and pipe not closed - closing.")
			if ($main::Debug);
	}
}


1;

