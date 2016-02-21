#!/usr/bin/perl
use FileHandle;
use Fcntl;
use VOCP;
use VOCP::Vars;
use strict;


=head1 toggleEmail2Vm.pl

=head2 NAME

toggleEmail2Vm - Turn email to voice mail forwarding on or off for a VOCP mail box


=head2 SYNOPSIS

/path/to/toggleEmail2Vm.pl "BOXNUMBER*PASSWORD"

For example,

/usr/local/vocp/bin/toggleEmail2Vm.pl "100*7838"

Would toggle (turn off if currently on or on if currently off) email2vm processing 
for box 100, assuming it is a mail box and it's password is 7838.

=head2 DESCRIPTION

This program is used by xvocp and potentially by a command shell or script box to
toggle the state of email to voicemail delivery using text-to-speech.  It assumes the
box is owned by a valid system user, that the box is indeed a 'mail' type box and that
text-to-speech has been appropriately configured.  See the doc/text-to-speech.txt and
doc/email-to-speech.txt HOWTOs for full details.

To use this program from the VOCP telephone interface, create a script box or command
shell selection with these parameters:

owner: root
input: raw
run: /path/to/toggleEmail2Vm.pl
output: tts

When accessing the box through the phone, you will need to enter "BOXNUMBER*BOXPASSWORD"
using the DTMF keys.  


=head2 AUTHOR INFORMATION

LICENSE

    email2vm.pl, part of the VOCP voice messaging system.
    Copyright (C) 2002 Patrick Deegan
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


Visit the official site: http://www.VOCPsystem.com or get in touch with me through
the about page at http://www.psychogenic.com.

=cut



use vars qw {
		$Debug
	};
	
$Debug = 0;

my $CommandLine = shift @ARGV;


{
	error("No box specified, aborting.", 1)
		unless ($CommandLine);
	
	
	error("Invalid input $CommandLine", 2)
		unless ($CommandLine =~ /^(\d+)\*(\d+)$/);
	
	
	my $boxnumber = $1;
	my $password = $2;
	
	# Create VOCP and VOCP::Util::DeliveryAgent objects
	my $options = {
		'genconfig'	=> $VOCP::Vars::DefaultConfigFiles{'genconfig'},
		'boxconfig'	=> $VOCP::Vars::DefaultConfigFiles{'boxconfig'},
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1,
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck		
	};
	
	my $vocp = VOCP->new($options);
	
	error("Could not create a new VOCP object - aborting.", 3) 
		unless ($vocp);
	
	my $type = $vocp->type($boxnumber);
	
	error("Invalid input, aborting.", 4) 
		unless ($type && $type eq 'mail');
	
	
	error("Invalid input, aborting.", 5) 
		unless ($vocp->check_password($boxnumber, $password));
	
	
	my $boxowner = $vocp->owner($boxnumber);
	
	error("This box has no owner.  Aborting.", 6)
		unless ($boxowner && $boxowner ne 'none');
	
	my ($name,$passwd,$uid,$gid,
 		$quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam($boxowner);
		
	error("Problem retrieving info for the box owner.  Aborting", 7)
			unless ($name && ($name eq $boxowner) && $dir && -e $dir && -d $dir);
	
	error("Invalid home directory specified for box owner. Aborting", 8)
			unless ($dir =~ m|^/|);
			
	error("Don't have permission to write to user home. Aborting", 9)
		unless (-w $dir);

		
	my $dontDeliverFile = "$dir/" . $VOCP::Vars::Defaults{'stopEmail2VmFile'} . ".$boxnumber";
	print STDERR "Dont deliver filename: $dontDeliverFile\n" if ($Debug > 1);
	if (-e $dontDeliverFile)
	{
		
		#error("Can't write to don't deliver file. Aborting", 10)
		#	unless( -w $dontDeliverFile);
		my ($fdev,$fino,$fmode,$fnlink,$fuid,$fgid,$frdev,$fsize,
                      $fatime,$fmtime,$fctime,$fblksize,$fblocks) = stat($dontDeliverFile);
		
		error("The don't deliver file is owned by someone else. Aborting.", 11)
			unless ($uid == $fuid);
		
		
		error("Something is wrong with the Don't Deliver File.  Aborting", 12)
			unless (-f $dontDeliverFile);

		my $numUnlinked = unlink $dontDeliverFile;
		
		error("Could not remove the don't deliver file.  Aborting", 13)
			unless ($numUnlinked && (! -e $dontDeliverFile));
		
		print "Email to Voice Mail has been\nturned ON for box $boxnumber.\n";
		exit(0);
	}
	
	# Must create the don't deliver file
	#error("Can't write the don't deliver file. Aborting", 14)
	#		unless( -w $dontDeliverFile);
	my $fileHandle = FileHandle->new() || error("Could not create a new File Handle object.  Aborting", 15);
	
	error("Could not safely create the Don't deliver file.  Aborting.", 16)
		unless ($fileHandle->open($dontDeliverFile, Fcntl::O_RDWR()|Fcntl::O_CREAT()|Fcntl::O_EXCL()));
		
	
	$fileHandle->print("Delete this file to enable email to voicemail delivery for box $boxnumber\n");
	
	if ($> == 0 || $< == 0)
	{
		chown $uid, $gid,  $dontDeliverFile;
	}
	
	$fileHandle->close();
	
	error("Tried to create Don't deliver File but it is nowhere to be found.  aaaaah!!", 16)
		unless(-e $dontDeliverFile);
		
	
	print "Email to Voice Mail has been suspended for\nbox $boxnumber and is now OFF.\n";
	exit(0);
	
	
}


sub error {
	my $message = shift;
	my $exitStatus = shift || 255;
	
	VOCP::Util::log_msg("$0 [$$]: $message") if ($Debug);
	print "$message\n";
	exit ($exitStatus);
}
				
	
	
