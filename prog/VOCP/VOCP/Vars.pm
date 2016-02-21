package VOCP::Vars;

use strict;

=head1 VOCP::Vars


=head2 NAME 

VOCP::Vars - contains VOCP system wide configuration and defaults.


=head1 AUTHOR

LICENSE

    VOCP::Vars module, part of the VOCP voice messaging system package.
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

use vars qw {
		%Exit
		%Defaults
		$Data_con_request
		$VocpLocalDir
		%DefaultConfigFiles
		@Valid_box_types
		@Valid_cmd_return_types
		@ValidDevices
		$BackupTempDir
		$VERSION
	};
$VERSION = '0.9.3';
################## USER Modifiable values ###################	
$VocpLocalDir = '/usr/local/vocp';
$BackupTempDir = '/tmp';
%DefaultConfigFiles = (
			'genconfig'	=> '/etc/vocp/vocp.conf',
			'boxconfig'	=> '/etc/vocp/boxes.conf',
			
		);


###################### End user config ######################
@Valid_box_types = ( 	'mail',
			'pager',
			'command',
			'faxondemand',
			'script',
			'group',
			'exit',
			'receivefax',
			'none',
			);
@Valid_cmd_return_types	 = ('exit', 'output', 'file', 'tts', 'sendfax');

# Valid device types for VOCP::Device::Factory et al.  Ordered here by popularity.
@ValidDevices = ('vgetty', 'local', 'none', 'vgettyold'); 
				
%Defaults = (
		'timeout'	=> 6,
		'numrepeat'	=> 3,
		'device'	=> 'DIALUP_LINE',
		'tempdir'	=> '/tmp',
		#'tempdir'	=> (getpwuid($>))[7],
		'pvftooldir'	=> '/usr/local/bin',
		'commanddir'	=> '/var/spool/voice/commands',
		'messagedir'	=> '/var/spool/voice/messages',
		'inboxdir'	=> '/var/spool/voice/incoming',
		'vocplocaldir'	=> '/usr/local/vocp',
		'voice_device_type'	=> 'vgetty',
		'genconfig'	=> $DefaultConfigFiles{'genconfig'},
		'boxconfig'	=> $DefaultConfigFiles{'boxconfig'},
		'calllog'	=> '/var/log/vocp-calls.log',
		'rootboxnum'	=> '001',
		'loginnum'	=> '999',
		'stopEmail2VmFile'	=> '.vocpStopEmail2Vm',
		'xferToBoxFile'	=> '.xferToBox',
		'language'	=> 'en',
		
		
	);


%Exit = (

	'DATA'		=> '1', #Determined by vgetty
	'FAX'		=> '2', #Determined by vgetty
	'DATAORFAX'	=> '3', #Determined by vgetty
	# Errors
	
	'MAXERRORS'	=> '248',
	'FILE'		=> '249',
	'AUTH'		=> '250',
	'VGETTY'	=> '251',
	'BADTYPE',	=> '252',
	'MISSING' 	=> '253',
	'EXISTS' 	=> '254',
	'UNDEF' 	=> '255',
	);
	
$Data_con_request = 'D';

unless (-e $Defaults{'tempdir'} && -w $Defaults{'tempdir'})
{
	if (-e $BackupTempDir && -w $BackupTempDir)
	{
		$Defaults{'tempdir'} = $BackupTempDir;
	} else {
		die "VOCP::Vars - Can't find a suitable temp dir (tried $Defaults{'tempdir'} and $BackupTempDir - set default";
	}
}

unless (-x $Defaults{'pvftooldir'} . '/pvftormd')
{
	if (-x '/usr/bin/pvftormd')
	{
		 $Defaults{'pvftooldir'} = '/usr/bin';
	} elsif (-x '/bin/pvftormd')
	{
		 $Defaults{'pvftooldir'} = '/bin';
	} else {
		die "VOCP::Vars - Can't seem to find a 'pvftormd' executable anywhere - set default";
	}
}
		



1;
