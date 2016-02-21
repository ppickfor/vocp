#!/usr/bin/perl 


use MIME::Parser; # Requires the MIME::Tools package

use VOCP::Util::DeliveryAgent;
use VOCP::Util;
use VOCP::Vars;
use VOCP::Strings;

use strict;

use vars qw {
		$Debug
		$DefaultTempDir
		$Lang
		$MaxChars
		$ShortenURLs
		$noTempFiles
	};

################## CONFIGURATION ##########################
$MaxChars = 375; # Longest message to send to TTS

$Lang = 'en'; # May be 'en' or 'fr'
$DefaultTempDir = '/tmp';
$Debug = 0;
$ShortenURLs = 1; # replace http://www.hohoho.com/whatever by URL at hohoho.com
$noTempFiles = 1; # If true, avoid using temp files - keep all in memory (may need alot...)
################# END CONFIGURATION #######################

$ENV{'ENV'} = '';
$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin';
$ENV{'CDPATH'} = '';
$ENV{'BASH_ENV'}="";


=head1 email2vm.pl

=head2 NAME

email2vm - converts and email message to a VOCP voice mail message.


=head2 SYNOPSIS

/path/to/email2vm.pl BOXNUMBER [BOXNUMBER2 [BOXNUMBER3]]

Will deliver email (translated using TTS to a sound file) entered on
standard input (STDIN) to all valid boxes passed as command line args
(BOXNUMBER, BOXNUMBER2, ...).

For setup instructions, see the VOCP doc/text-to-speech.txt and 
doc/emails-to-speech.txt HOWTOs.

=head2 DESCRIPTION

The email2vm program takes 1 or more command line arguments (which must
be numeric and be valid VOCP mail box numbers), reads an *EMAIL* message on STDIN
and uses a text-to-speech engine (festival) to translate the email to sound.

It then uses a VOCP::Util::DeliveryAgent object to translate the resulting sound file
to a format acceptable to VOCP voice mail box and deliver it.

=head2 NOTES

The program will only deliver messages to boxes owned by the uid of the program
caller, unless that uid is 0 (root), in which case emails may be delivered to any
valid VOCP voice mail box.

You may wish to edit this file's CONFIGURATION section - namely the 
$MaxChars variable which sets the maximum number of characters to do the TTS on.


You can use the VOCP txttopvf file to translate arbitrary text to sound

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


$VOCP::Util::Die_on_error = 0;

my @DeliverToBox;


# Only accept numerical box numbers
foreach my $box (@ARGV)
{
	if ($box =~ /^(\d+)$/)
	{
		$box = $1; # untaint
		push @DeliverToBox, $box;
	}
}

# Must have at least 1 valid box
VOCP::Util::error("email2vm.pl - No valid boxes to deliver to...")
	unless (scalar @DeliverToBox);

{
	
	# Create VOCP and VOCP::Util::DeliveryAgent objects
	my $options = {
		'genconfig'	=> $VOCP::Vars::DefaultConfigFiles{'genconfig'},
		'boxconfig'	=> $VOCP::Vars::DefaultConfigFiles{'boxconfig'},
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1,
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck		
	};
	
	my $vocp = VOCP->new($options);
	
	# Reuse the VOCP object for the delivery agent
	$options->{'vocp'} = $vocp;
	
	my $deliveryAgent = VOCP::Util::DeliveryAgent->new($options)
				|| VOCP::Util::error("Could not create a new VOCP::Util::DeliveryAgent object!");
	

	# Use a MIME::Parser (from MIME::tools) to parse the message
	my $parser = new MIME::Parser;
	
	my $tmpdir = $VOCP::Vars::Defaults{'tempdir'} || $vocp->{'tempdir'} || $DefaultTempDir;
	
	VOCP::Util::error("Cannot write to tempdir '$tmpdir' - Aborting")
		unless (-w $tmpdir);
	
	$parser->output_under($tmpdir);
	if ($noTempFiles)
	{
		$parser->output_to_core(1);
		$parser->tmp_to_core(1);
	}
	# Read in the email
	my $mailEntity = $parser->parse(\*STDIN) || VOCP::Util::error("Could not parse message from STDIN");

	my $mailType = $mailEntity->mime_type();

	# Extract most appropriate text content (may be html)	
	my ($content, $type) = extract_text_content($mailEntity);
	
	# Get the From: from the header and clean it up
	my $header = $mailEntity->head();
	my ($from, $subject);
	$from = $header->get('From') if ($header);
	$subject = $header->get('Subject') if ($header);
	chomp($from);
	my $cleanFrom = $from;
	$cleanFrom =~ s/[<>]/ /g;
	$cleanFrom =~ s/[^\w\d\@\_\."'\s\-]//g;
	
	
	# Clean up the content
	$content = $VOCP::Strings::Strings{$Lang}{'emailfrom'} . "$cleanFrom\n$subject\n$content";
	
	
	if ($ShortenURLs)
	{
		$content =~ s!(http|ftp)://([^/]+)(/\S+)?!$2!ismg;
		print STDERR "Shortened URL...";
	}
	
	$content =~ s/[^\S\.]{12,}/ /smg; # Strings that are too long
	$content =~ s/^>.*//smg; # Remove response lines
	$content =~ s/<[^>]*>//smg; # Get rid of any html (including the contents of <TAG>s
	$content =~ s/&[\w\d#]+?;/ /smg; 	# Get rid of HTML encoded values &nbsp; etc.  Yes, this is cheap but it is 
					# safe and will avoid hearing a lot of nonsense in the TTS output.
	$content =~ s/(.)\1{5,}/$1/smg; # Remove excessive repeats ('xxxxxxxxxxxxxxxxxxx' becomes 'x')
	$content =~ s/[^\s\w\d\@\.,\!#'-]+/ /g; # Get rid of all 'unknown quantities'.
	$content =~ s/\s\s+/ /smg; # Get rid of large numbers of consecutive spaces
	
	
	# Make sure it's not too long or we'll be listening to this message for 2 hours...
	if (length($content) > $MaxChars)
	{
		$content =~ s/^(.{$MaxChars}).*/$1 . Message truncated./sm;
	}
	
	# Make sure the cleanup worked (it should)
	if ($content !~ m|^([\s\w\d\@\.,\!#'-]+)$|sm)
	{
		VOCP::Util::error("Could not clean email contents... Aborting.");
	}
	# untaint me
	$content = $1;
	
	my %metaInfo = (
				'source'	=> 'email',
				'from'		=> $cleanFrom || 'none',
			);
	
	# Deliver to each command line box
	foreach my $boxnumber (@DeliverToBox)
	{
		my $type = $vocp->type($boxnumber);
		if ($type eq 'mail')
		{
			my $boxowner = $vocp->owner($boxnumber);
			my ($name,$passwd,$uid,$gid,
 				$quota,$comment,$gcos,$dir,$shell,$expire) = getpwnam($boxowner);
				
			if ($name && ($name eq $boxowner) && $dir)
			{
				# Skip delivery if a don't deliver file exists for this boxnumber in the owner's home and
				# is owned by the box owner.
				my $dontDeliverFile = "$dir/" . $VOCP::Vars::Defaults{'stopEmail2VmFile'} . ".$boxnumber";
				if (-e $dontDeliverFile && -f $dontDeliverFile)
				{
					my ($fdev,$fino,$fmode,$fnlink,$fuid,$fgid,$frdev,$fsize,
                      					$fatime,$fmtime,$fctime,$fblksize,$fblocks) = stat($dontDeliverFile);
							
					if ($fuid == $uid)
					{
		
						VOCP::Util::log_msg("Skipping delivery of email to box $boxnumber because $dontDeliverFile exists")
							if ($Debug);
						next;
					} # end if the file is owned by box owner
				
				} # end if the dontdeliver file is present for this box
				
			} # end if the box owner is a valid system user and has an existing home dir
		} # end if this is a mail box
		elsif ($type ne 'group')
		{
			# You can only deliver to mail and group (?) boxes...
			VOCP::Util::log_msg("Trying to deliver email2vm to a box of type '$type'?? Skipping.");
			next;
		}
		
		$deliveryAgent->deliverData($boxnumber, $content, 'txt', %metaInfo);
	}
	
	exit(0);
}


# extract_text_content searches for the best text match (text/plain is favored over text/html)
# it calls itself recursively for multipart content
sub extract_text_content {
	my $entity = shift || return undef;
	my $type = $entity->mime_type();
	
	
	if ($entity->is_multipart())
	{
		my ($foundText, $foundType);
		my $numParts = $entity->parts();
		for (my $i=0; $i<$numParts; $i++)
		{
			my ($text, $type) = extract_text_content($entity->parts($i));
			if ($text && $type)
			{
				if ( (!$foundText) || ($foundType ne 'text/plain' && $type eq 'text/plain'))
				{
					$foundText = $text;
					$foundType = $type;
				}
			}
			
		}
		
		return ($foundText, $foundType);
	} elsif ($type =~ m|^text|)
	{
		my $content = $entity->stringify_body();
		return ($content, $type);
	} else {
		return (undef, undef);
	}
	
}
	
	
	
