#!/usr/bin/perl

my $License = join( "\n",  
qq|################### install_vocp.pl #####################|,
qq|######                                            #######|,
qq|######    Copyright (C) 2000-2003  Pat Deegan     #######|,
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

use strict;

use vars qw {
	$Cp
	@Message_dirs
	$VOCP_conf_dir
	$Spool_dir
	%Spool_subdirs
	%LocalProgram_files
	%Other_Local_exes
	%Config_files
	@Doc_files
	@Com_shell_examples
	$Version
	$VOCP_group
	$Groupadd
	$LocalDir
	%PerlModule_dirs
	$Pwd
	%RequiredModules
	@LogFiles
	};

# The required modules list below contains entry of the form:
#
# CPAN Module name	=> [ABSOLUTELYREQUIREDBOOL, REQUIREDBYSTRING]
#
# If ABSOLUTELYREQUIREDBOOL is true, installation will fail when not found

%RequiredModules = (
					'Audio::DSP'	=> [0, 'VOCPLocal and xVOCP GUI'],
					'XML::Mini'		=> [1, 'VOCP Core'],
					'Modem::Vgetty'	=> [1, 'VOCP Core'],
					'Tk'			=> [0, 'CallCenter, xVOCP, VOCPhax GUIs'],
					'Tk::JPEG'		=> [0, 'CallCenter, xVOCP, VOCPhax GUIs'],
					'Crypt::CBC'		=> [0, 'VOCPweb'],
					'Crypt::Blowfish'	=> [0, 'VOCPweb'],
					'MIME::Parser'	=> [0, 'Email-to-VoiceMail'],
		);
	
my $AudioDSPModLocation = 'prog/dependencies/Audio-DSP-0.02b/';

my $ModemVgettyModLocation = 'prog/dependencies/Modem-Vgetty-0.04/';

my $VOCPDepsLocation = 'prog/dependencies/';
$Version = '0.9.2';

$LocalDir = '/usr/local/vocp';

$Cp = '/bin/cp';

$VOCP_conf_dir = "/etc/vocp";

$Spool_dir = '/var/spool/voice';

@Message_dirs = ( 
		'messages/num',
		'messages/day',
		'messages/system',
		'messages/menu',
		'messages',
	);

%Spool_subdirs = (
		'incoming'	=> 'incoming',
		'cache'		=> 'incoming/cache',
		'messages'	=> 'messages',
		'commands'	=> 'commands',
		'num'		=> 'messages/num',
		'day'		=> 'messages/day',
		'system'	=> 'messages/system',
		'menu'		=> 'messages/menu',
		);


%PerlModule_dirs = (
	'VOCP'		=> 'prog/VOCP',
);

%LocalProgram_files = (
	'installer'	=> 'install_vocp.pl',
	'sampleconv'	=> 'modify_sample_rate.pl',
	'vocpweb'	=> 'vocpweb',
	'progbin'	=> 'prog/bin',
	'progrun'	=> 'prog/run',
	'proglib'	=> 'prog/lib',
	'images'	=> 'images',
	'sounds'	=> 'sounds',
	'testfax'	=> 'images/faxtest.g3',
);


%Other_Local_exes = (
	
	'vocp'	=> 'prog/vocp.pl',
);

	
%Config_files = (
	'genconf'	=> 'prog/vocp.conf',
	'boxconf'	=> 'prog/boxes.conf',
	'boxshadow'	=> 'prog/boxes.conf.shadow',
	'cidconf'	=> 'prog/cid-filter.conf',
	'boxsample'	=> 'prog/boxes.conf.sample',
);

@LogFiles = ('/var/log/vocp.log', '/var/log/vocp-calls.log');


@Doc_files = (
		'doc/*',
	);

@Com_shell_examples = ('commands/seleclisting.pl', 'commands/ip.pl',  'commands/date.pl',  'commands/echo.pl', 'commands/motd.pl');

$VOCP_group = 'vocp';

$Groupadd = '/usr/sbin/groupadd';


my %Install_type = (
	'full' 		=> '1',
	'upgrade'	=> '2',
	'sound'		=> '3',
	);

# Installs are the relevant files, sets permissions and 
# converts the sound files.
#
# Uses a bunch of system() calls - not pretty, but not
# too important, used only once...
#
# To be done: Check return values of all system() calls...

#main 
{

	$Pwd = `pwd`;
	chomp($Pwd);

	print "\n\nVOCP installer\n"
		. "$License\n\n"
		."This program will install VOCP $Version.\n"
		."You may just press the ENTER key to accept "
		."the [default] value for any question.\n";

	my $AgreeLicense = 'n';
	print "\n\nYou understand that the VOCP system, it's source code and all supporting documents and resources are\n"
		. "\nCopyright (C) 2000-2003 Patrick Deegan, Psychogenic INC\n"
		. "\nand subject to the terms and conditions described in the accompanying LICENSE file.  You have read the LICENSE and "
		. "agree to comply with the terms and conditions described therein? [$AgreeLicense]: ";

	option(\$AgreeLicense);
	
	unless ($AgreeLicense =~ m|^\s*[yY]|)
	{
		print "\nYou must agree to comply to the terms of the LICENSE before using VOCP or any parts thereof.\n"
			. "Aborting installation.\n\n";
		exit(0);
	}
	
	print "\n\n";
		
	########################### INSTALL Type ################################
	# Type of installation
	my $install = $Install_type{'full'};
	print "Enter:\n$Install_type{'full'} for full vocp install,\n"
	     ."$Install_type{'upgrade'} if you are upgrading a previous version of VOCP (read doc/upgrading.txt!),\n"
	     ."$Install_type{'sound'} if you only wish to convert the sound files "
	     ."to rmd format\n[$install]: ";	     
	option(\$install);
	
	unless ($install =~ /^\d$/ && $install < 4) {
		print "Invalid selection ($install), please try again...\n\n";
		exit(1);
	}
	
	die "You must be root to do a full install or upgrade"
		if (( $install == $Install_type{'full'} 
			|| $install == $Install_type{'upgrade'}) && $> != 0);

	if ($install == $Install_type{'upgrade'}) { # Skip sound file conversion
		print "Skipping sound file conversion.\n";
	} else {
		convert_sound() ;
	}
	
	# If user selected only to convert, we're done.
	if ($install == $Install_type{'sound'}) {
		print "Done.\n\n";
		exit(0);	
	}

	system("touch " . join(" ", @LogFiles));

	########################### Dependencies ################################
	my $numSpaces = 30;
	my $numReqs = 0;
	my $numFound = 0;

	print "\n\nChecking current state of dependencies (perl Modules):\n";
	foreach my $module (sort keys %RequiredModules)
	{

		my $req = $RequiredModules{$module};

		$numReqs++;
		my $absolute = $req->[0];
		my $reqBy = $req->[1];
		my $modStr = "Module: $module ...";
		print $modStr;
		my $spaces = ' ' x ($numSpaces - length($modStr));

		eval "require $module;";

		if ($@)
		{
			print "$spaces NOT found - needed by '$reqBy' but is NOT available.\n";
			print ' ' x $numSpaces;
			if ($absolute)
			{
				print " Module: $module is REQUIRED for basic VOCP operation.\n\n";
			} else {
				print " Module: $module is OPTIONAL.\n\n";
			}
		} else {
			$numFound++;

			print "$spaces FOUND.\n";
		}
	}



	if ($numFound != $numReqs)
	{
	
		my $installDeps = 'y';
		print "\nCertain modules now required by VOCP were not found.  You must install the modules marked REQUIRED before proceeding.  "
			. "You may:\n\t- Abort and manually install any dependencies\n\t- Proceed with current configuration.\n\t- Attempt to automatically install all missing dependencies.\n\nInstall ALL dependencies automatically (you must be connected to the Internet)? [$installDeps]: ";
		option(\$installDeps);
	
		if ($installDeps =~ /^\s*[yY]/)
		{
			print "\nInstalling dependencies...\n";
			
			# Special case for moded Audio::DSP
			chdir($AudioDSPModLocation);
			system("perl Makefile.PL; make; make install");
			chdir($Pwd);
			
			# Special case for moded Modem::Vgetty
			chdir($ModemVgettyModLocation);
			system("perl Makefile.PL; make; make install");
			chdir($Pwd);
			
			chdir ($VOCPDepsLocation);
			system("perl ./install_deps.pl");
			print "\nBase system install deps returned.  You will need to ensure Crypt::CBC and Crypt::Blowfish are available ";
			print "if you wish to run VOCPweb.\n";
			
			print "\nDone\n\n\n";
		} else {
			print "\nSkipping module installation.\n\n";
		}
	
	
		foreach my $module (sort keys %RequiredModules)
		{
			
			my $req = $RequiredModules{$module};

			my $absolute = $req->[0];
			my $reqBy = $req->[1];
			my $modStr = "Module: $module ...";
			print $modStr;
			my $spaces = ' ' x ($numSpaces - length($modStr));
					
			eval "require $module;";
	
			if ($@)
			{
				if ($absolute)
				{
					print "$spaces NOT FOUND.";
					print "\n\n**** Error ****\nThe $module module does not seem to be installed and is REQUIRED for VOCP operation.\n";
					exit(0);
				}
	
	
			} else {
				print "$spaces found.\n";
			}
		}

	} # end if found less requirements than needed
	
	chdir($Pwd);

	########################### Directories ################################
	
	print "\nCreating directories...\n";
	print "\t$VOCP_conf_dir\n";
	system("mkdir -p $VOCP_conf_dir");
	

	# Documentation dir
	my $docdir = "$LocalDir/doc";

	print "\t$docdir\n";
	# We call system to use the -p option
	system("mkdir -p $docdir");
	
	print "\t$Spool_dir\n";
	system("mkdir -p $Spool_dir");
	
	foreach my $dir (values %Spool_subdirs) {
		print "\t$Spool_dir/$dir\n";
		system("mkdir -p $Spool_dir/$dir");
	}
	
	print "\nDone.\n";

	########################### VOCP modules ################################
	#Copy program files
	chdir($Pwd);
	print "Installing VOCP Perl modules...\n";
	chdir($PerlModule_dirs{'VOCP'});
	system("perl Makefile.PL; make; make install");
	print "\nDone\n\n\n";
	chdir($Pwd);


	
	########################### Utility programs and files ################################

	print "Copying files...\n";
	
	print "\nConfiguration files\n";
	foreach my $file (values %Config_files) {
		print "\t$file to $VOCP_conf_dir\n";
		my $filename;
		if ($file =~ m|([^/]+$)|) { #usually will
			$filename = $1;
		}
		if ($filename && (-e "$VOCP_conf_dir/$filename") ) {
			print "$filename exists.  Saving new file as $filename.new - do a diff to see what has changed\n";
			system("$Cp $file $VOCP_conf_dir/$filename.new");
		} else {
			system("$Cp $file $VOCP_conf_dir");
		}
	}
	
	print "\nDocs\n";
	foreach my $file (@Doc_files) {
		print "\t$file to $docdir\n";
		system("$Cp $file $docdir");
	}
	
	
	
	chdir($LocalProgram_files{'progbin'});
	
	my $compiler = $ENV{'CC'} || 'gcc';
	print "Creating pwcheck setgid wrapper\n";
	system("$compiler -o pwcheck pwcheck.c");
	print "Creating xfer_to_vocp setuid wrapper\n";
	system("$compiler -o xfer_to_vocp xfer_to_vocp.c");
	my $haveTTS = 'n';
	print "\nDo you wish to use Text-to-speech (to hear emails, etc.) AND do you have the Festival TTS engine installed [$haveTTS]: ";
	option(\$haveTTS);

	if ($haveTTS =~ m|^\s*[yY]|)
	{
		my $notFound = 1;
		my $festDir;
		do 
		{
			print "Under which directory can Festival's bin/text2wave program be \nfound (enter full path up to bin/text2wave): ";
			option(\$festDir);
			chomp($festDir);
			
			# Correct if they've entered the full path including the executable
			if ($festDir =~ m|^(.*)/bin/text2wave$|)
			{
				$festDir = $1;
			}
			
			if (-d $festDir && -x "$festDir/bin/text2wave")
			{
				print "text2wave found!\n";
				$notFound = 0;
			} else {
				print "Cannot find an executable at $festDir/bin/text2wave.\n";
				$festDir = '';
			}
		} while ($notFound);

		$festDir =~ s|/$||;
		system("perl -pi -e \"s|txt2wavProg = '/path/to/bin/text2wave'|txt2wavProg = '$festDir/bin/text2wave'|g\" txttopvf")
				if ($festDir);
	}



	chdir ($Pwd);
	
	foreach my $file (values %LocalProgram_files) {
		print "Installing $file to $LocalDir\n";
		system("$Cp -R $file $LocalDir");
	}
	
	foreach my $file (values %Other_Local_exes) {
		print "Installing $file to $LocalDir/bin\n";
		system("$Cp -R $file $LocalDir/bin");
	}
	
	
	
	print "\nPVF files to $LocalDir\n";
	foreach my $dir (@Message_dirs) {
		#print "\t$dir/*.pvf to $Spool_dir/$dir\n";
		system("mkdir -p $LocalDir/$dir");
		system("$Cp $dir/*.pvf $LocalDir/$dir");
	}
		
	print "\nCommand shell examples and stock programs\n";
	my $cmdspooldir = "$Spool_dir/$Spool_subdirs{'commands'}";
	foreach my $command (@Com_shell_examples)
	{
		my $filename;
		if ($command =~ m|.+/([^/]+)$|)
		{
			$filename = $1;
		} else {
			$filename = $command;
		}
		next if (-e "$cmdspooldir/$filename");
		
		
		print "\t$filename to $cmdspooldir\n";
		system("$Cp $command $cmdspooldir");
		chmod oct('0755'), "$cmdspooldir/$filename";
	}	

	if ($install == $Install_type{'upgrade'}) { #Don't copy messages
	
		print "Not overwriting sound files (upgrade)\n";
		
		print "\nWhich name would you like to use for the vocp system group?\n[$VOCP_group]: ";
		
		
	} else {
		print "\nSystem messages\n";
		foreach my $dir (@Message_dirs) {
			print "\t$dir/*.rmd to $Spool_dir/$dir\n";
			system("$Cp $dir/*.rmd $Spool_dir/$dir");
		}
	
	
		
	
		# Do a little security
		print "\nWe will create a vocp group to enable the console message script "
			. "to read the box configuration, while keeping the file (which will "
			. "contain passwords) safe.\n";
	
		print "\nWhat should the name of the new group be?\n[$VOCP_group]: ";
		# The incoming dir - so the the messages script can delete messages belonging to the owner
		chmod oct('1777'), "$Spool_dir/$Spool_subdirs{'incoming'}";
		
	}

		
	option(\$VOCP_group);
	
	while (! -x $Groupadd)
	{
		print "\nWhat is the full path of the groupadd program on your system?\n"
			. "[$Groupadd]: ";
		option(\$Groupadd);
	}
	
	print "\nCreating group and setting permissions on boxes.conf and messages.pl...\n";
	system("$Groupadd $VOCP_group");
		

	# Do a little work on permissions
	# The messages.pl script and the boxes config	
	my $uid = getpwnam('root');
	my $gid = getgrnam($VOCP_group);
	unless ($gid) {
		print "Unable to find $VOCP_group group.  Setting group owner to root.\n";
		$gid = getgrnam('root');
	}
	
	chown $uid, $gid, $LocalDir . '/bin/messages.pl', $VOCP_conf_dir . '/boxes.conf', $VOCP_conf_dir . '/boxes.conf.shadow',
			"$Spool_dir/$Spool_subdirs{'cache'}", "$LocalDir/bin/pwcheck.pl", "$LocalDir/bin/pwcheck";
	
	chmod oct('0644'), $VOCP_conf_dir . '/boxes.conf';
	chmod oct('0640'), $VOCP_conf_dir . '/boxes.conf.shadow';
	chmod oct('2755'), $LocalDir . '/bin/messages.pl';
	
	if (-e $LocalDir . '/bin/pwcheck')
	{
		chmod oct('2755'), $LocalDir . '/bin/pwcheck';
	} else {
		chmod oct('2755'), $LocalDir . '/bin/pwcheck.pl';
	}
	chmod oct('0755'), $LocalDir . '/bin/xvocp.pl';
	chmod oct('0755'), $LocalDir . '/bin/boxconf.pl';
	
	chmod oct('0775'), "$Spool_dir/$Spool_subdirs{'cache'}";
	
	
	print "\nDone.\nVOCP should now be fully installed!\n"
		. "Be sure to read the documentation to set it up or check out the web"
		. " site at http://www.VOCPsystem.com (latest) or in $docdir.  Be sure to read the"
		. "vocpweb/README file if you wish to use the web interface!\n\n"
		. "I'd appreciate your comments, bug reports or simply "
		. "confirmation that you are using this software at prog\@vocpsystem.com\nEnjoy!\n";
	
	
}


sub convert_sound {

	#Do conversion of sound files
	my ($pvftormd, $found);
	do {
		# locate pvftormd
		my $pvftoolsdir = '/usr/local/bin';
		print "Where is the pvftormd executable (included "
		     ."with mgetty) installed on your system\n"
		     ."[$pvftoolsdir]: ";
		option(\$pvftoolsdir);
		$pvftormd = $pvftoolsdir . '/pvftormd';
		if (-x $pvftormd) {
			print "\n";
			system("$pvftoolsdir/pvftormd -L");
			$found++;
		} else {
		
			print "\nCould not find executable $pvftoolsdir/pvftormd!\n\n";
		}
		
	} until ($found);
	
	my $pvftormdopt = 'Lucent 5';
	
	print "\nListed above are the supported modems and "
	      ."compression types.  You should already know which "
	      ."of these apply to your modem (if not see the "
	      ."documentation included on vgetty or the website). "
	      ."Please enter the options that apply to your modem, "
	      ."for example, $pvftormdopt\n[$pvftormdopt]: ";
	option(\$pvftormdopt);
	
	print "\nConverting sound files, this can take a while...\n";
	
	foreach my $dir (@Message_dirs) {
		
		system("ls $dir/*.pvf | sed 's/\.pvf//' | xargs -i $pvftormd $pvftormdopt {}.pvf {}.rmd");
		
	}
	print "Done: sound files converted to rmd format.  "
		     ."Test them with:\n"
		     ."vm play -s -v ./sounds/path/to/file.rmd\n\n";
		     
	return 1;
}



################### option ######################
# option REF_STR
#  where REF_STR is a reference to the option of 
#  interest.
# option modifies the corresponding option if
# anything but <enter> was entered by the user.
########################################################
sub option {
	my $r_option = shift || die "Called option without an option!\n";
	
	my $input = <STDIN>;
	chomp ($input);
	
	$$r_option = $input if ($input);


}
	
