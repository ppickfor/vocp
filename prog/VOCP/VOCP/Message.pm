package VOCP::Message;

use VOCP::Util;
use VOCP::Vars;


use vars qw {
		$VERSION
	};
	

$VERSION = $VOCP::Vars::VERSION;

use strict;


=head1 NAME

	VOCP::Message - Represent a single message for the VOCP system.


=head1 AUTHOR

LICENSE

    VOCP::Message module, part of the VOCP voice messaging system package.
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




sub new {
	my $class = shift;
	my $filename = shift;
	
	my $self = {};
        
        bless $self, ref $class || $class;
        
	$self->init();
	if ($filename) {
		
		$self->{'origfilename'} = $filename;
		$self->filename($filename);
		
		
	}
	
	return $self;
}

sub init {
	my $self = shift;
	$self->{'location'} = "";
	$self->{'box'} = "";
	$self->{'number'} = "";
	$self->{'rawflags'} = "";
	$self->{'flags'}->{'read'} = 0;
	$self->{'flags'}->{'flag'} = 0;
	$self->{'format'} = 'rmd';
}


sub format {
	my $self = shift;
	my $format = shift; # optionally set
	
	
	if (defined $format)
	{
		$self->{'format'} = $format;
	}
	
	return $self->{'format'};
}
	
sub filename {
	my $self = shift;
	my $filename = shift; #optionally set
	
	
	if (defined $filename)
	{
		if ( $filename !~ m|(.*/)(\d+)-(\d+)(-([\w\d]+))?\.[\w\d]{1,4}$| )
		{
			VOCP::Util::error("Invalid filename passed to VOCP::Message::filename(): '$filename'");
		} 
		
		my $location = $1;
		my $box = $2;
		my $number = $3;
		my $flags = $5;
		$self->location($location);
		$self->box($box);
		$self->number($number);
		$self->rawFlags($flags, 'DONTSAVE') if ($flags);
	}
	
	
	my $name = $self->location() . $self->box() . '-' . $self->number();
	my $flags = $self->rawFlags();
	$name .= "-$flags" if ($flags);
	$name .= '.' . $self->{'format'};
	
	return $name;
	
}	

sub location {
	my $self = shift;
	my $location = shift; #optionally set
	
	if (defined $location)
	{
		VOCP::Util::error("VOCP::Message::location() - Location '$location' invalid, must be FULL path.")
			unless ($location =~ m|^/|);
		
		$self->{'location'} = $location;
		$self->{'location'} .= '/' unless ($self->{'location'} =~ m|/$|);
	}
	
	return $self->{'location'};
	
}

sub box {
	my $self = shift;
	my $box = shift; #optionally set
	
	if (defined $box)
	{
		$self->{'box'} = $box;
	}
	
	return $self->{'box'};
}

sub number {
	my $self = shift;
	my $number = shift; #optionally set
	
	if (defined $number)
	{
		$self->{'number'} = $number;
	}
	
	return $self->{'number'};
}

sub rawFlags {
	my $self = shift;
	my $flags = shift; #optionally set
	my $dontsave = shift; # do NOT save changes to filename
	
	if (defined $flags)
	{
		$self->{'rawflags'} = $flags;
		if ($flags =~ /r/i)
		{
			$self->flagRead(1, $dontsave);
		}
		if ($flags =~ /f/i)
		{
			$self->flagFlag(1, $dontsave);
		}
		
	}
	
	return $self->{'rawflags'};
}


sub flagRead {
	my $self = shift;
	my $read = shift;  #optionally set
	my $dontsave = shift; # do NOT save changes to filename

	
	if (defined $read)
	{
		if ($read) 
		{
			$self->{'rawflags'} .= 'r' unless ($self->{'rawflags'} =~ /r/i);
			$self->{'flags'}->{'read'} = 1;
		} else {
			$self->{'rawflags'} =~ s/r//ig;
			$self->{'flags'}->{'read'} = 0;
		}
		$self->saveChanges() unless ($dontsave);
	}
	
	return $self->{'flags'}->{'read'};
}

sub flagFlag {
	my $self = shift;
	my $flag = shift;  #optionally set
	my $dontsave = shift; # do NOT save changes to filename

	
	if (defined $flag)
	{
		if ($flag) 
		{
			$self->{'rawflags'} = $self->{'rawflags'}.'f' unless ($self->{'rawflags'} =~ /f/i);
			$self->{'flags'}->{'flag'} = 1;
		} else {
			$self->{'rawflags'} =~ s/r//ig;
			$self->{'flags'}->{'flag'} = 0;
		}
		$self->saveChanges() unless ($dontsave);
	}
	
	return $self->{'flags'}->{'flag'};
}

sub saveChanges {
	my $self = shift;
	
	VOCP::Util::error("Cant' VOCP::Message::saveChanges(): oldfilename not set.")
		unless ($self->{'oldfilename'});
	
	my $filename = $self->filename();
	
	if ($filename ne $self->{'oldfilename'})
	{
		system($VOCP::Util::Mv . ' ' . $self->{'oldfilename'} . " $filename");
		$self->{'oldfilename'} = $filename;
		return 1;
	} 
	
	return 0;
}
	
sub getDetails {
	my $self = shift;
	
	my $filename = $self->filename();
	
	
	my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                      		$atime,$mtime,$ctime,$blksize,$blocks) = stat($filename);
	
	my $ret = {
			'ino'	=> $ino,
			'mode'	=> $mode,
			'nlink'	=> $nlink,
			'uid'	=> $uid,
			'gid'	=> $gid,
			'size'	=> $size,
			'time'	=> $mtime || $ctime || $atime || '1',
			'filename'	=> $self->getRelativeFilename($filename),
			'flags'		=> $self->rawFlags(),
			'number'	=> $self->number(),
			'location'	=> $self->location(),
		};
	return $ret;
	
}	


		
sub getRelativeFilename {
	my $self = shift;
	my $filename = shift || $self->filename();
	
	VOCP::Util::error("Can't  VOCP::Message::getRelativeFilename() - No fname set!")
		unless ($filename);
	
	$filename =~ s|.*/||g;
	
	return $filename;
	
}

sub getAttrib {
	my $self = shift;
	my $attrib = shift;
	
	return undef unless ($attrib);
	
	my $details = $self->getDetails();
	
	return $details->{$attrib};
}


sub delete {
	my $self = shift;
	
	my $loc = $self->location();
		
	my $filename = $self->filename();

	VOCP::Util::error("VOCP::Message::delete() - No location set for message '$filename'")
		unless ($loc);
		
	VOCP::Util::error("VOCP::Message::delete() - No filename set for message")
		unless ($filename);
		
	$filename = VOCP::Util::full_path($filename, $loc, 'SAFE');
	
	VOCP::Util::error("VOCP::Message::delete() - Can't seem to find '$filename'")
		unless (-e $filename);
		
	my $numdel =  unlink $filename;
	
	return $numdel
}
	
=head1 AUTHOR

LICENSE

    VOCP::Message module, part of the VOCP voice messaging system package.
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


VOCP, VOCP::Box, VOCP::Util

http://VOCPsystem.com

=cut





1;

__END__
	


