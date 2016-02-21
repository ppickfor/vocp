package VOCP::Config::Simple;

use strict;
use FileHandle;

use VOCP::Vars;
use VOCP::Util;

=head1 VOCP::Config::Simple


=head2 NAME 

VOCP::Config::Simple - centralizes the process of reading simple

key	value

configuration files.

=head1 AUTHOR

LICENSE

    VOCP::Config::Simple module, part of the VOCP voice messaging system package.
    Copyright (C) 2003 Patrick Deegan
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


=head2 VOCP::Config::Simple::read FILE

Opens and reads the configuration info from FILE.
Returns a hash reference containing configuration information.

=cut


sub read {
	my $conffile = shift || VOCP::Util::error("Must pass a config file to parse to VOCP::Config::Simple::read()");
	
	VOCP::Util::log_msg("Reading config file: $conffile")
		if ($main::Debug > 1);
	
	
	my $config = FileHandle->new();
	$config->open("<$conffile") 
		|| VOCP::Util::error("Unable to open conf file ($conffile): $!");
	
	my $configHash = {};
	while (my $line = $config->getline()) { #Parse each line
	
		next if ($line =~ /^\s*(#|$)/); #ignore empty and #...
		
		if ($line =~ /^\s*([\S]+)\s+"([^"]+)"\s*$/)
		{
			# Special case of config line like
			# key "a single value with spaces"
			$configHash->{$1} = $2;
			
		} elsif ($line =~ /^\s*([\S]+)\s+([\S]+)(\s+([\S]+)(\s+([\S]+))?)?/) { #a valid line
			if ($6) {
				$configHash->{$1}{$2}{$4} = $6
					unless (defined $configHash->{$1}{$2}{$4}); # params to new() override
			} elsif ($4) {
				$configHash->{$1}{$2} = $4
					unless (defined $configHash->{$1}{$2}); # params to new() override
			} else {
				$configHash->{$1} = $2
					unless (defined $configHash->{$1}); # params to new() override
			}
		} else {
			
			VOCP::Util::log_msg("Ignoring invalid line in config: $line");
		}
		
	}
	
	$config->close();
	#close(CONFIG)
	#	|| VOCP::Util::log_msg("$conffile did not close nicely.$!");
		
	
	# Get the gid if the 'group' option is set
	if (defined $configHash->{'group'}) {

		my $gid = getgrnam($configHash->{'group'});
		
		VOCP::Util::error("Group option set to $configHash->{'group'} but I can't find a matching gid",
			$VOCP::Vars::Exit{'MISSING'})
			unless (defined $gid);
		
		$configHash->{'groupgid'} = $gid;
	}
	
	return $configHash;
}



1;
