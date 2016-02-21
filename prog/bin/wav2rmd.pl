#!/usr/bin/perl



=head1 NAME

wav2rmd.pl - one step wave to rmd converter

=head1 SYNOPSIS

wav2rmd.pl /path/to/file1.wav [/path/to/file2.wav ...]

OR

cd /path/to/wavs

/usr/local/vocp/bin/wav2rmd.pl *.wav


=head1 DESCRIPTION


wav2rmd allows you to avoid the tedious wav->pvf, pvf->rmd conversion for
your VOCP system messages.

It assumes you have correctly configured the 

 
rmdformat
rmdcompression
rmdsample	

values in vocp.conf


RMD files will be saved in same directory as the wav files are located, 
filename.wav being saved as filename.rmd.

=head1 AUTHOR INFORMATION

LICENSE

    VOCP Call Center GUI, part of the VOCP voice messaging system.
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

use vars qw {
	$Debug
};

$Debug = 0;

unless (scalar @ARGV)
{
	print "Usage\n$0 WAVFILE [WAVFILE2 [WAVFILE3 [...] ] ]\nCreates corresponding .rmd files for your modem\n";
	exit(1);
}

{

	my $options = {
		'genconfig'	=> $VOCP::Vars::Defaults{'genconfig'},
		'boxconfig'	=> '',
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1, # no need for logging here...
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck
		
		};
	
	my $Vocp = VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP object");
		
	
	
	$TmpDir =  $Vocp->{'tempdir'} || $VOCP::Vars::Defaults{'tempdir'} || '/tmp' ;
	unless (-w  $TmpDir)
	{
		print STDERR "Can't write to $TmpDir\n"
			if ($Debug);
		$TmpDir = (getpwuid($>))[7];
		unless ( -w $TmpDir)
		{
			print STDERR "Can't write to $TmpDir either - aborting.\n";
			exit (1);
		}
	}
	
	my $RmdFormat = $Vocp->{'rmdformat'} || die "No rmdformat set in vocp.conf";
	my $RmdCompression = $Vocp->{'rmdcompression'};
	die "No rmdcompression set in vocp.conf" unless (defined $RmdCompression);
	my $RmdSample = $Vocp->{'rmdsample'} || die "No rmdsample rate set in vocp.conf";	

	foreach my $wavFile (@ARGV)
	{
		my $fname ;
		my $dir;
		if ($wavFile =~ m|^((.*)/)?([^/]+).wav$|)
		{
			$dir = $2 || '.';
			$fname = $3;
		} else {
			print STDERR "Strange filename '$wavFile' - skipping.\n";
			next;
		}
		
		unless (-e $wavFile && -r $wavFile)
		{
			print STDERR "Can't find or can't read '$wavFile' - skipping.\n";
			next;
		}
		
		if (-e "$dir/$fname.rmd")
		{
			print STDERR "The file '$dir/$fname.rmd' exists - won't overwrite, please delete it. Skipping\n";
			next;
		}
		
		system("wavtopvf $wavFile | pvfspeed -s $RmdSample | pvftormd $RmdFormat $RmdCompression > $dir/$fname.rmd");
	}
	
	print "Done\n";
	exit(0);
}
	
	
