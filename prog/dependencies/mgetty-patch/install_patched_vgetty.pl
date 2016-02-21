#!/usr/bin/perl

use strict;

my $License = join( "\n",  
qq|###################  patch_vgetty.pl ####################|,
qq|######                                            #######|,
qq|######       Copyright (C) 2002  Pat Deegan       #######|,
qq|######            All rights reserved             #######|,
qq|#                                                       #|,
qq|#   This program is free software; you can redistribute #|,
qq|#   it and/or modify it under the terms of the GNU      #|,
qq|#   General Public License as published by the Free     #|,
qq|#   Software Foundation; either version 2 of the        #|,
qq|#   License, or (at your option) any later version.     #|,
qq|#                                                       #|,
qq|#   This program is distributed in the hope that it will#|,
qq|#   be useful, but WITHOUT ANY WARRANTY; without even   #|,
qq|#   the implied warranty of MERCHANTABILITY or FITNESS  #|,
qq|#   FOR A PARTICULAR PURPOSE.  See the GNU General      #|,
qq|#   Public License for more details.                    #|,
qq|#                                                       #|,
qq|#   You should have received a copy of the GNU General  #|,
qq|#   Public License along with this program; if not,     #|,
qq|#   write to the Free Software Foundation, Inc., 675    #|,
qq|#   Mass Ave, Cambridge, MA 02139, USA.                 #|,
qq|#                                                       #|,
qq|#   You may contact the author, Pat Deegan, on the      #|,
qq|#   http://www.psychogenic.com contact page.            #|,
qq|#                                                       #|,
qq|#                                                       #|,
qq|#########################################################|,
);

use vars qw {
		$MgettyTarBall
		$MgettyDir
};

$MgettyTarBall = '/path/to/mgetty-1.1.30.tar.gz';
$MgettyDir = 'mgetty-1.1.30' ;
{
	print "$License\n\n\n";
	
	unless (-e './test.pvf')
	{
		print "Please run this executable from within the VOCP mgetty-patch directory (cd there first)\n";
		exit(1);
	}
	
	unless ($> == 0 || $< == 0)
	{
		print "Please run this executable as the root user\n";
		exit(2);
	}
	
	my $forceproceed = 0;
	foreach my $p (split(':', $ENV{'PATH'}), '/usr/local/sbin/', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/bin', '/sbin')
	{
		last if ($forceproceed);
		
		if (-e "$p/mgetty" || -e "$p/vgetty")
		{
			my $proceed = 'n';
			print "\n\nMgetty or vgetty seems to be already installed in $p.  If this is a system installation (deb or rpm) ";
			print "it may be wise to remove the package (using rpm -e, for instance) before proceeding...\n";
			print "Shall we proceed with the new installation anyway ? [$proceed]: ";
			
			option(\$proceed);
			unless ($proceed =~ m|^[yY]|)
			{
				print "Aborting mgetty installation.\n";
				exit(3);
			}
			$forceproceed = 1;
		}
	}
	
	
	do {
		print "\n\nEnter full path to mgetty source tar.gz\nfile [$MgettyTarBall]: ";
		option(\$MgettyTarBall);
	} while (! (-e $MgettyTarBall && -f $MgettyTarBall) );
	
	print "\n**************\nUnpacking m/vgetty source\n";
	if ($MgettyTarBall =~ m|\.tar\.gz$|i)
	{
		system("tar zxvf $MgettyTarBall");
	} elsif ($MgettyTarBall =~ m|\.tar.bz2$|i)
	{
		system("tar jxvf $MgettyTarBall");
	} elsif ($MgettyTarBall =~ m|\.tar$|i)
	{
		system("tar xvf $MgettyTarBall");
	} else {
		print "Sorry - '$MgettyTarBall' is neither a .tar.gz, a .tar.bz2 nor a .tar file - don't know how to unpack.";
		exit(4);
		
	}
	
	unless (-e "./$MgettyDir" && -d "./$MgettyDir")
	{
		print "Can't find the ./$MgettyDir after unpacking source... aborting\n";
		exit(5);
	}
	
	
	print "\n**************\nPatching source...\n";
	system("patch -p0 < ./force_detect.patch");
	system("cp test.pvf ./$MgettyDir/voice/contrib/Pat_Deegan");
	
	print "Done\n";
	print "\n**************\nMoving into ./$MgettyDir\nBuilding Mgetty\n";
	chdir("./$MgettyDir");
	system("cp policy.h-dist policy.h");
	system("make");
	
	print "\n**************\nBuilding Vgetty\n";
	chdir("./voice");
	system("make");
	my $proceed = 'y';
	print "\nDone\n\n**************\nShall we proceed and install the patched version of m/vgetty? [$proceed]: ";
	option(\$proceed);
	unless ($proceed =~ m|^\s*[Yy]|)
	{
		print "Aborting installation\n";
		exit(6);
	}
	
	# stuff that seems to bug out on certain servers...
	if (-x "/usr/sbin/useradd")
	{
		system("/usr/sbin/userad fax");
	}
	system("mkdir -p /usr/local/man/man1");
	system("mkdir -p /usr/local/man/man3");
	
	chdir("../");
	system("make install");
	chdir("./voice");
	system("make install");
	
	if (-d "/usr/local/etc/mgetty+sendfax" && ! (-e "/usr/local/etc/mgetty+sendfax/voice.conf"))
	{
		print "Copying default voice.conf to /usr/local/etc/mgetty+sendfax/\n";
		system("cp voice.conf-dist /usr/local/etc/mgetty+sendfax/voice.conf");
	}
	
	print "Done.\n";
	
	
	exit(0);
}
	
sub option {
	my $r_option = shift || die "Called option without an option!\n";
	
	my $input = <STDIN>;
	chomp ($input);
	
	$$r_option = $input if ($input);


}	
