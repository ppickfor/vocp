#!/usr/bin/perl -T

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};



=head1 NAME

pwcheck.pl - Password validation for underprivelged users

=head1 AUTHOR INFORMATION

LICENSE

    pwcheck.pl, part of the VOCP voice messaging system.
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


Address bug reports and comments to: vocp@psychogenic.com or come
and see me at http://www.psychogenic.com.


=cut

use VOCP;
use VOCP::Vars;
use strict;

use vars qw {
		$ERROR
		$OK
		$Debug
		$Usage
};

$Debug = 0;

$ERROR = 250;
$OK = 0;

$Usage = "$0\nBOXNUM PASSWORD expected on standard in on a single line.";
my $input = <>;

unless (defined $input)
{
	print STDERR "$Usage\n";
	exit($ERROR);
}

chomp($input);

unless ($input =~ m|^(\d+)\s+(.+)$|)
{
	print STDERR "Invalid boxnumber";
	exit($ERROR);
}

my $boxnum = $1;
my $password = $2;


unless (defined $password)
{
	print STDERR $Usage;
	exit($ERROR);
}

chomp ($password);



{
	my $options = {
		'genconfig'	=> $VOCP::Vars::DefaultConfigFiles{'genconfig'},
		'boxconfig'	=> $VOCP::Vars::DefaultConfigFiles{'boxconfig'},
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1,
		};
		
	my $Vocp = VOCP->new($options)
		|| VOCP::error("Unable to create new VOCP instance.");
		
		
	my $validPass = $Vocp->check_password($boxnum, $password);
	
	if ($validPass)
	{
		print "Password is valid\n" if ($Debug);
		exit($OK);
	} else {
		print "Password is INvalid\n" if ($Debug);
		exit($ERROR);
	}
}

