package VOCP::Util;

use VOCP::Vars;
use File::Copy;
use FileHandle;
use Fcntl;
use VOCP::PipeHandle;
use Data::Dumper;


use strict;

=head1 NAME

	VOCP::Util - Various utility methods used by the VOCP system.


=head1 ABSTRACT

This perl module provides helper methods to other VOCP::XXX modules,
such as filename checks, safe temp file creation, Base64 en/decoding,
error and logging, etc.



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




=head1 FUNCTIONS

All the functions below should be called with

VOCP::Util::FUNCTIONNAME( PARAMS );


=cut

use vars qw {
	$Mv
	$Die_on_error
	$TestBoxNum
	$DEADBEEF
	$VERSION
};
$VERSION = $VOCP::Vars::VERSION;
$Die_on_error = 1;

$Mv = '/bin/mv';


$TestBoxNum = '9999999996';
$DEADBEEF = 'FEEBDAED';





=head2 full_path FILE DEFAULTDIR [SAFE]

Checks that FILE is a full path file name.  If
not, the sub prepends DEFAULTDIR to FILE to create
a full path name.

If SAFE is true, extra checks are performed to insure that
the filename contains neither '/../' nor the suspicious characters
';|`' (minus the quotes).

Returns a full path file name.


=cut

sub full_path {
	my $file = shift;
	my $defaultdir = shift;
	my $safe = shift; #optional
	
	
	VOCP::Util::error("Must pass file and defaultdir to VOCP::full_path", $VOCP::Vars::Exit{'MISSING'})
		unless ($file && $defaultdir);
	
	# A little paranoid - double check our paths		
	my $fullfile = "";
	
	if ($file =~ m|^/|)
	{
		$fullfile = $file;
	} else {
		$defaultdir .= '/' unless ($defaultdir =~ m|/$|);
		$fullfile  =  $defaultdir;
		$fullfile .= $file;
	}
	
	if ($safe) { # Extra safety check		
		# Check for stupid ../../../etc/passwd shite
		VOCP::Util::error("Weird filename! $file")
			if ($file =~ m|/\.\./| || $file =~ /[;|`\*]/);
	}
	
	return $fullfile;
	
}

=head2 clean_filename FILENAME

Cleans (untaints) and returns a list of (FILENAME, EXTENSION) without
a path.  Returns undef if taint check fails or the filename has an 
unexpected configuration.

=cut

sub clean_filename {
	my $filename = shift;
	
	my ($file, $ext);
	# Extract (and untaint) the filename
	if ($filename =~ m|/([^/]+)\.([\w\d]+)$|) {
		$file = $1;
		$ext = $2;
	} else {
		if ($filename =~ m|^([\w\d.-]+)\.([\w\d]+)$|) {
			$file = $1;
			$ext = $2;
		} else {
			print STDERR "Invalid filename $filename found in clean_filename()";
			return undef;
		}
	}
	
	
	print STDERR "clean_filename() cleaned $filename.  Returning: $file , $ext"
		if($main::Debug > 1);
	
	
	return ($file, $ext);
	
}	

	
=head2 dtmf_to_text DTMF

Translates the sequence of digits DTMF, to text.  Text is 
entered via the dialpad by using the letters associated 
with each key (e.g. 'abc' for '2').

To enter a letter the user first selects a dialpad button,
say '5', and then the letter on the button he wishes to add
to the text.  Thus the combination '51' is 'j', '52' is 'k'
and '53' is 'l'.  To write 'hello' the user would enter 
(check your nearest keypad):

 h  e  l  l  o

42 32 53 53 63

To enter actual digits, precede the digits with '0' (instead
of the usual '1', '2' or '3'). So '05' is '5'.

Exceptions:
MaBell decided that the 1 and 0 keys were too important,
so 'q' and 'z' are missing...  we shall, of course improvise
in order to save the leftout letters:

a 1 and a 0 can form the letter q, so the combo is '10'
and cursive z looks like 3 (use '30').

Here is the list of exceptions and some extras with their 
(admitedly shabby) mnemonics:

LTR	COMBO	MNEM

q	10	With 1 and 0 you can make q

z	30	Cursive looks like 3

-	41	- is like 1 turned 90 degrees

@	42	@ is another kind of 'a' (the '2' key)

.	45	There is often a little . on 5 to let you
		know where the center of the pad is (in the 
		dark, say).	


=cut

my @DTMF_to_text;

sub dtmf_to_text {
	my $dtmf = shift;

	return undef 
		unless (defined $dtmf);
		
	print STDERR "Translating '$dtmf' to text\n"
		if ($main::Debug);
	
	# Slight optimization, only fills when necessary,
	# Also, this is nice place to fill it - here where it's relevent
	unless ($#DTMF_to_text > 0 ) { #The array is empty, we shall fill
		print STDERR "Initialising translation matrix\n"
			if ($main::Debug );
			
		my $u = undef; #shortcut
	
		#We fill @DTMF_to_text with array refs
		
		#Digits - '0X' gives the text: X where X is a digit
		$DTMF_to_text[0] = [ 0 .. 9];
		
		# Note that, MaBell decided that 1 and 0 were too important,
		# so 'q' and 'z' are missing...  we shall, of course improvise
		# in order to save the leftout letters:
		# a 1 and a 0 can for the letter q and cursive z looks like 3 (use 30)
		
		#Look at your phone dialpad, it will tell you the secret of this order 
		
		#Keys:		     0,  1, 2,  3,  4,  5,  6,  7,  8,  9 
		#X1 gives Xth element of $DTMF_to_text[1] ($DTMF_to_text[1]->[X])
		$DTMF_to_text[1] = ['q', $u,'a','d','g','j','m','p','t','w'];
		
		#X2 gives Xth element of $DTMF_to_text[2] ($DTMF_to_text[2]->[X])
		$DTMF_to_text[2] = [$u, $u,'b','e','h','k','n','r','u','x'];
		
		#X3 gives Xth element of $DTMF_to_text[3] ($DTMF_to_text[3]->[X])
		$DTMF_to_text[3] = ['z', $u,'c','f','i','l','o','s','v','y'];
		
		#X4 -- the exeptions 0,  1,  2,  3, 4,  5
		$DTMF_to_text[4] = [$u, '-','@',$u, $u,'.'];
		
	}

	# We group the input in pairs
	my @combos;
	while ( $dtmf =~/(..)/g) {
		push @combos, $1;	
	}

	print STDERR "GOT COMBOs: " , join(':', @combos), "\n"
		if ($main::Debug);
	my $text = "";
	foreach my $combo (@combos) {
	
		if ($combo =~ /^(\d)(\d)$/) {
		
			my $key = $1;
			my $pos = $2;
			
			my $letter;
			if (defined $DTMF_to_text[$pos]->[$key] ) { #valid combo
			
				print STDERR "Got $DTMF_to_text[$pos]->[$key] from combo $combo\n"
					if ($main::Debug > 1);
			
				$text .= $DTMF_to_text[$pos]->[$key];
			
			} else { #Not a valid combination
				
				print STDERR "Got invalid combo $combo, adding space\n"
					if ($main::Debug);
					
				$text .= ' ';
				
			}
			
		} else { # Combo is funny looking
		
			print STDERR "Got funny looking combo $combo (not digits), ignoring\n"
				if ($main::Debug);
				
		} # End if digits
		
	} #End foreach
	
	
	print STDERR "Final translated text is '$text'\n"
		if ($main::Debug);
						
	
	return $text;
	
}
			


=head2 MIME64_Encode STR

 
Encodes STR to base 64 and returns result.
Code snippet from:
# Script:       | FAQ Manager (Interaction Program)
# Version:      | 1.0 
# By:           | Jason Berry (i2 Services, Inc. / CGI World)
# Contact:      | jason HAT cgi-world DAWT com

Used with permission of author.


=cut

sub MIME64_Encode {
    my($in)  = $_[0];                                     # text to encode
    my(@b64) = (('A'..'Z','a'..'z','0'..'9'),'+','/');                # Base 64 char set to use
    my($out) = unpack("B*",$in);                          # Convert to binary
    $out=~ s/(\d{6}|\d+$)/$b64[ord(pack"B*","00$1")]/ge;  # convert 3 bytes to 4
    while (length($out)%4) { $out .= "="; }               # Pad string with '='
	$out =~ s/(.{1,76})/$1\n/g;

    return $out;                                          # Return encoded text
}



=head2 MIME64_Decode STR

Decodes Base 64 STR and returns result.

=cut

sub MIME64_Decode {
    my($in)  = $_[0];                                     # encoded text to decode
    my(%b64);                                             # Base 64 char set hash
    my($out);
    my $i;
                                                 # decoded text variable
    for(('A'..'Z','a'..'z','0'..'9'),'+','/'){ $b64{$_} = $i++ }      # Base 64 char set to use
    $in = $_[0] || return "MIME64 : Nothing to decode";   # Get input or return
    $in =~ s/[^A-Za-z0-9+\/]//g;                          # Remove invalid chars
    $in =~ s/[A-Za-z0-9+\/]/unpack"B*",chr($b64{$&})/ge;  # b64 offset val -> bin
    $in =~ s/\d\d(\d{6})/$1/g;                            # Convert 8 bits to 6
    $in =~ s/\d{8}/$out.=pack("B*",$&)/ge;                # Convert bin to text
    return $out;                                          # Return decoded text
}


=head2 create_email FROM TO SUBJECT TEXT [ATTACHEMENT AT_TYPE AT_ENCODE AT_NAME]

Creates a properly formatted email message, possibly with an attachement

=cut

sub create_email {
	my $from = shift;
	my $to = shift;
	my $subject = shift;
	my $text = shift;
	my $attachement = shift; # optional

	## MP3 Support mods by Ali Naddaf begin here...
	my $attachmentFormat = shift || 'wav'; # Optional
	my $attach_type = shift || "audio/x-".$attachmentFormat;
	my $attach_enc = shift || 'base64';
	my $attach_name = shift || "message.".$attachmentFormat;
	## END Ali Naddaf MP3 Support mods
	
	
	
	my $email = qq|From: $from\nMIME-Version: 1.0\nTo: $to\n|
		   .qq|Subject: $subject\n|;
		   

	if ($attachement)
	{	
		my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 );
		my $boundary="-x----------";
		$boundary .=  join ("", @chars[ map { rand @chars } (1 .. 15) ]) . 'VOCP-boundary';

		$email .= qq|Content-Type: multipart/mixed;\n boundary="$boundary"\n\n|
		 .qq|This is a multi-part message in MIME format.\n|;
	
		$email .= qq|--$boundary\nContent-Type: text/plain; charset=us-ascii\nContent-Transfer-Encoding: 7bit\n\n|
		 .qq|$text\n\n|;

	
		$email .= qq|--$boundary\nContent-Type: $attach_type;\n name="$attach_name"\nContent-Transfer-Encoding: $attach_enc\n|
		 .qq|Content-Disposition: inline;\n filename="$attach_name"\n\n|;
		 
		$email .= qq|$attachement\n--$boundary--|;
	} else
	{
		$email .= qq|Content-Type: TEXT/PLAIN; charset=US-ASCII\n\n|;
		
		$email .= qq|$text|;
	}
	
	return $email;
}


=head2 rmd2attachement %PARAMS

Creates and return (an optionally Base64 encoded) string in format
ATTACHEMENT_FORMAT.

Valid PARAMS keys are

 
'inputfile' 	- required
'outputformat'	- required 
'base64encode'	- true or false
'rmdsample'
'pvftooldir'
'tempdir'

=cut


sub rmd2attachment {
	my %params = @_;
	
	my $msg = $params{'inputfile'} || VOCP::Util::error("Must pass a message filename to VOCP::Util::create_attachment");
	my $attachmentFormat = $params{'outputformat'} || VOCP::Util::error("Must pass an attachment format (ogg,mp3,wav) to create_attachment");
	my $base64encode = $params{'base64encode'}; # optionally, base64 encode.
	
	
	unless (-r $msg)
	{
		VOCP::Util::error("Could not read $msg: $!");
	}
	
	
	my $attach;
	
	# Convert to wav format and attach it
	
	# Create a unique tempname
	my $baseName = $params{'tempdir'} || $VOCP::Vars::Defaults{'tempdir'};
	$baseName .= "/vocpattch$$";
	
	my ($tmpPvfHandle, $tmpPvfName) = VOCP::Util::safeTempFile($baseName);
	
	unless ($tmpPvfHandle && $tmpPvfName)
	{
		VOCP::Util::error("VOCP::Util::rmd2attachment() Could not create a tempfile based on '$baseName'");
	}
	
	unlink $tmpPvfName;
	$tmpPvfHandle->close();
	
	my ($error, $message) = VOCP::Util::X2pvf(	'inputfile'	=> $msg, 
							'outputfile'	=> $tmpPvfName, 
							'inputformat'	=> 'rmd', 
							'nooverwrite'	=> 1, 
							'rmdsample' 	=> $params{'rmdsample'},
							'pvftooldir'	=> $params{'pvftooldir'});
	
	
	
	
	VOCP::Util::error($message)
		if ($error);
	

	my ($tmpAttHandle, $tmpAttName) = VOCP::Util::safeTempFile($baseName);
	unless ($tmpAttHandle && $tmpAttName)
	{
		VOCP::Util::error("VOCP::Util::rmd2attachment() Could not create a tempfile based on '$baseName'");
	}
	
	unlink $tmpAttName;
	$tmpAttHandle->close();
	## MP3 Support mods by Ali Naddaf begin here...
	($error, $message) = VOCP::Util::pvf2X($tmpPvfName, $tmpAttName, $attachmentFormat, undef, 'NOOVERWRITE');
	## END Ali Naddaf MP3 Support mods
	
	unlink $tmpPvfName;
	
	VOCP::Util::error($message)
		if ($error);

	## MP3 Support mods by Ali Naddaf begin here...
	my $attachfh = FileHandle->new();
	
	$attachfh->open("<$tmpAttName")
		|| VOCP::Util::error("Could not open $tmpAttName: $!");
		
	$attach = join('', $attachfh->getlines());
	VOCP::Util::log_msg("Converted message to $attachmentFormat")
			if ($main::Debug > 1);
			
	unlink ($tmpAttName);
	
	## END Ali Naddaf MP3 Support mods
			
	$attach = VOCP::Util::MIME64_Encode($attach) if ($base64encode);
	
	return $attach;
}




=head2 pvf2X PVFFILE OUTPUTFILE FORMAT

converts PVFFILE to another format (FORMAT), producing OUTPUTFILE

=cut

sub pvf2X {
	my $pvffile = shift;
	my $soundfile = shift;
	my $formattype = shift;
	my $options = shift || ""; # optional param to pass to pvftoX prog
	my $nooverwrite = shift; # optional 
	my $pvftooldir = shift || $VOCP::Vars::Defaults{'pvftooldir'};
	
	if ($nooverwrite && -e $soundfile) {
		return (1, "pvf2X: $pvffile already exists");
	}

	
	my $pvftool = $pvftooldir . "/pvfto$formattype";
	unless (-x $pvftool) {
		$pvftool = "$VOCP::Vars::VocpLocalDir/bin/pvfto$formattype";
		unless (-x $pvftool)
		{
			$pvftool = "$VOCP::Vars::VocpLocalDir/pvfto$formattype";
			unless (-x $pvftool)
			{
				return (1, "Unable to locate pvfto$formattype");
			}
		}
	}
	
	#$pvftool =~ s|//|/|g;
	
	my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($soundfile);
	unless ($tmpFileHandle && $tmpFileName)
	{
		VOCP::Util::error("VOCP::Util::pvf2X() Could not create a tempfile based on '$soundfile'");
	}
	
	
		
	VOCP::Util::log_msg("VOCP::Util::pvf2X() Running $pvftool $options $pvffile $soundfile");

	my $pvfToXfd = VOCP::PipeHandle->new();
	
	if (! $pvfToXfd->open("$pvftool $options $pvffile |"))
	{
		unlink $tmpFileName;
		$tmpFileHandle->close;
		return (1, "VOCP::Util::pvf2X() Could not open '$pvftool $options $pvffile' $!");
	}
	
	$tmpFileHandle->autoflush();
	while (my $inputLine = $pvfToXfd->getline())
	{
		$tmpFileHandle->print($inputLine);
	}
	$pvfToXfd->close();
	
	
	if ($nooverwrite && -e $soundfile) {
		unlink $tmpFileName;
		$tmpFileHandle->close();
		return (1, "pvf2X: $pvffile already exists");
	}
	copy($tmpFileName, $soundfile);
	
	unlink $tmpFileName;
	$tmpFileHandle->close();
	
	return (0, "pvf2X: SUCCESS");
}



=head2 X2pvf %PARAMS

The X2pvf function is used to convert from format X (see below) to the Portable Voice Format.  The PVF files are often 
used to create modem-dependant rmd (raw modem data) files.

inputfile may be any file found on the system. The supported inputformats for filename depend on the installed
XXXtopvf programs.  Both the pvftooldir and the vocp local dir (/usr/local/vocp) will be searched for a matching
XXXtopvf file.

For instance, calling:

VOCP::Util::X2pvf(	'inputfile'	=> "/home/me/list.txt", 
			'inputformat'	=> 'txt',
			'outputfile'	=> "/home/me/list.pvf",
			'rmdsample'	=> 8000,
			'pvftooldir'	=> '/usr/local/bin');

will cause VOCP to search for a 'txttopvf' executable in pvftooldir and the VOCP local dir.  If found, 'txttopvf' will
be called to create the /home/me/list.pvf file.

There are no guarantees that this operation will succeed (the executable may not be found, problems may occur during 
execution, etc.)  Check the functions return values but, more importantly, select OUTPUTPVF files that are safe and do
not exist, then check that they've been created.

Returns a list (ERRORCODE, MESSAGE), where ERRORCODE is 0 on success.




=cut

sub X2pvf {
	my %params = @_;
	
	my $filename = $params{'inputfile'} || return (1, "VOCP::Util::X2pvf: Must pass an input filename");
	my $pvffile = $params{'outputfile'} || return (1, "VOCP::Util::X2pvf: Must pass an output filename");		
	my $format = $params{'inputformat'} || return (1, "VOCP::Util::X2pvf: Must pass an input format") ;		
	my $nooverwrite = $params{'nooverwrite'}; # optional
	my $sample = $params{'rmdsample'} || 8000;
	my $pvfToolDir = $params{'pvftooldir'} || $VOCP::Vars::Defaults{'pvftooldir'};
	
	
	if ($nooverwrite && -e $pvffile) {
		return (1, "X2pvf: $pvffile already exists");
	} 
	
	
	
	my $Xtopvf = "$pvfToolDir/${format}topvf";
	my $pvfspeed = "$pvfToolDir/pvfspeed";
	
	unless (-x $pvfspeed)
	{
		return (1, "Cannot locate the $pvfspeed executable");
	}
	
	unless (-x $Xtopvf) {
		$Xtopvf = "$VOCP::Vars::VocpLocalDir/${format}topvf";
		unless (-x $Xtopvf )
		{
			$Xtopvf = "$VOCP::Vars::VocpLocalDir/bin/${format}topvf";
			unless (-x $Xtopvf )
			{
				return (1, "Cannot locate ${format}topvf") ;
			}
		}
	}

	my ($tmpPvfFh, $tmpPvfName) = VOCP::Util::safeTempFile($pvffile);
	
	unless ($tmpPvfFh && $tmpPvfName)
	{
		return (1, "VOCP::X2pvf could not create a temp file based on '$pvffile'");
	}
	
	
	VOCP::Util::log_msg("Executing: $Xtopvf $filename")
		if ($main::Debug > 1);
	
	my $xtopvfh = VOCP::PipeHandle->new();
	$xtopvfh->open("$Xtopvf $filename |")
		|| return (1, "VOCP::X2pvf could not open '$Xtopvf $filename' for read.");
	
	
	my $tmpPvfContents = join("", $xtopvfh->getlines());
	$xtopvfh->close();
	
	unless ($tmpPvfContents) 
	{
		unlink $tmpPvfName;
		$tmpPvfFh->close();
		return (1, "$Xtopvf seems to have had a problem converting $filename to $pvffile")
	}
		
	$tmpPvfFh->autoflush();
	$tmpPvfFh->print($tmpPvfContents);
	
	
	if ($nooverwrite && -e $pvffile)
	{
		unlink $tmpPvfName;
		$tmpPvfFh->close();
		return (1, "X2pvf: $pvffile already exists (appeared during function call)");
	} 
	
	VOCP::Util::log_msg("Executing: $pvfspeed -s $sample $tmpPvfName $pvffile ")
		if ($main::Debug > 1);

	my $ret = system("$pvfspeed -s $sample $tmpPvfName $pvffile");

	return ($ret, "$pvfspeed seems to have had a problem converting pvffile to $sample sample rate ($ret)")
		if ($ret);
		
	unlink $tmpPvfName unless ($main::Debug > 2);
	$tmpPvfFh->close();

	return (0, $format . "2pvf: SUCCESS");
}



=head2 safeTempFile BASENAME

Safely creates a temporary file, with a random name based on BASENAME
(the filename will be random, something like BASENAME-tmp-RANDOML, and will
be opened O_EXCL|O_CREAT with mode 0600).

Returns an array containing:

(TEMPFILEHANDLE, TEMPFILENAME)

Where TEMPFILEHANDLE is a FileHandle object and TEMPFILENAME is a string.
Write to the open TEMPFILEHANDLE.  When done, unlink TEMPFILENAME and *then* close TEMPFILEHANDLE.

Example:

 
	my ($tempFh, $tempFname) = VOCP::Util::safeTempFile("/tmp/vocptmp$$");
	
	unless ($tempFh && $tempFname)
	{
		VOCP::Util::error("Could not create a tempfile!");
	}
	
	$tempFh->print("some stuff");
	
	# Use the temp file/handle
	
	unlink $tempFname;
	$tempFh->close();

=cut

sub safeTempFile {
	my $baseName = shift || return undef;
	my $extension = shift;
	
	
	VOCP::Util::error("VOCP::Util::safeTempFile() Please include FULL path for BASENAME")
		unless ($baseName =~ m|^/|);
	

	require Fcntl unless defined &Fcntl::O_RDWR;
	
	my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9);
	my $tempName;
	my $maxTry = 300;
	my $try = 0;
	my $oldumask = umask(0077);
	my $fileHandle = FileHandle->new();
	my $fail;
	do {
		$fail = 1;
		$tempName = $baseName . "-tmp-" . join ("", @chars[ map { rand @chars } (1 .. 7) ]);
		
		$tempName .= ".$extension" if ($extension);
		
		if ($fileHandle->open($tempName, Fcntl::O_RDWR()|Fcntl::O_CREAT()|Fcntl::O_EXCL()))
		{
			$fail = 0;
		}
		
		$try++;
		
	} while ($fail && $try <= $maxTry);
	
	umask($oldumask);
	
	if ($try > $maxTry)
	{
		return undef;
	}
	
	return ($fileHandle, $tempName);
	
}


sub Dump {
	
	return Dumper(shift);
}

=head2 error ERRORMSG [EXIT]

Logs ERRORMSG to STDERR and exits the program, using exit code
EXIT (use the %Exit hash for preset values) or $Exit{'UNDEF'} if EXIT not defined.

Note:  If die_on_error is set to true during the call to new() or 
VOCP::Die_on_error is set true, then error() will die instead of exiting
with an exit code.
This is usefull, for example, when wrapping calls to new() in an eval, 
to trap the errors.


=cut

sub error {
	my $error = shift;
	my $exit = shift; # optional
	
	# Set any messages involving the test box to dead beef
	$error =~ s|$TestBoxNum|FEEBDAED|; 
	
	$exit = 255
		unless (defined $exit);
	
	my $date = localtime(time);
	
	print STDERR "$0 $date [$$] Fatal Error: $error\n";
	
	die $error
		if ($Die_on_error);
	
	exit($exit);
	
}



sub log_msg {
	my @msg = @_;
	
	print STDERR "$0 [$$]: " , @msg, "\n";
	
	return;
}
	

=head1 AUTHOR

LICENSE

    VOCP::Util module, part of the VOCP voice messaging system package.
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

VOCP

http://VOCPsystem.com

=cut




1;

__END__
