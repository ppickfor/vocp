#!/usr/bin/perl


=head1 NAME

convert_boxconf.pl - Convert pre 0.9 boxes.conf files to the new (XML) format


=head1 SYNOPSIS

/path/to/convert_boxconf.pl /path/to/oldboxes.conf

Simply enter a new file name when prompted, e.g. /home/user/newboxes.conf

The files

 /home/user/newboxes.conf
 /home/user/newboxes.conf.shadow
 
will be created.  After verifying that they look right, as root:

# mv /home/user/newboxes.conf /etc/vocp/boxes.conf
# mv /home/user/newboxes.conf.shadow /etc/vocp/boxes.conf.shadow

# chown root:root  /etc/vocp/boxes.conf
# chown root:vocp  /etc/vocp/boxes.conf.shadow
# chmod 640 /etc/vocp/boxes.conf.shadow

That's it.


=head1 AUTHOR INFORMATION

LICENSE

    convert_boxconf.pl, part of the VOCP voice messaging system.
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


=head1 CREDITS

Thanks go out to Helene Poirier for designing the GUI and to 
Luis Padros for sending me an initial working version of a 
Perl Tk message retrieval GUI for VOCP.


=cut
use VOCP;
use VOCP::Config::Box;
use VOCP::Util;
use VOCP::Vars;

use Data::Dumper;
use strict;
use vars qw{
			$Debug
		};
$Debug = 0;

my $oldConfFile = shift @ARGV || $VOCP::Vars::DefaultConfigFiles{'boxconfig'};
my $genConfFile = shift @ARGV || $VOCP::Vars::DefaultConfigFiles{'genconfig'};

die "Can't find boxes.conf file '$oldConfFile'" unless (-e $oldConfFile);

die "Can't read boxes.conf file '$oldConfFile'" unless (-r $oldConfFile);

die "Can't write to  boxes.conf file '$oldConfFile'" unless (-w $oldConfFile);

{
	my $options = {
			'genconfig' => $genConfFile,
			'boxconfig'	=> $oldConfFile,
			'voice_device_type'	=> 'none',
			'nocalllog'	=> 1, # no need for logging here...
		};
	
	my $Vocp = VOCP->new($options)
		|| VOCP::Util::error("Could not initialize a new VOCP object?");

	my $href = $Vocp->getBoxesAsHash();

	print "Parsed config file - got:\n";
	print Dumper($href);

	my $boxConfig = VOCP::Config::Box->new();

	$boxConfig->fromHash($href);

	print "Will ouput:\n";
	print $boxConfig->toXMLString();

	print "\n\nEnter name of file to save: ";
	my $fname = <STDIN>;
	chomp ($fname);
	$Vocp->write_box_config($fname);

	print "\nDone.\n";
	exit(0);

}
