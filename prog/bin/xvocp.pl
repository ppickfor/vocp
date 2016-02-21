#!/usr/bin/perl -w

$|++;

my $License = join( "\n",  
qq|######################## xvocp.pl ########################|,
qq|####                                                  ####|,
qq|####  Copyright (C) 2003 Pat Deegan, Psychogenic.com  ####|,
qq|####               All rights reserved.               ####|,
qq|####                                                  ####|,
qq|#                                                        #|,
qq|#             VOCP Local message retrieval               #|,
qq|#                       interface                        #|,
qq|#                                                        #|,
qq|#              http://www.VOCPsystem.com                 #|,
qq|#                                                        #|,
qq|#                                                        #|,
qq|#                                                        #|,
qq|#   This program is free software; you can redistribute  #|,
qq|#   it and/or modify it under the terms of the GNU       #|,
qq|#   General Public License as published by the Free      #|,
qq|#   Software Foundation; either version 2 of the         #|,
qq|#   License, or (at your option) any later version.      #|,
qq|#                                                        #|,
qq|#   This program is distributed in the hope that it will #|,
qq|#   be useful, but WITHOUT ANY WARRANTY; without even    #|,
qq|#   the implied warranty of MERCHANTABILITY or FITNESS   #|,
qq|#   FOR A PARTICULAR PURPOSE.  See the GNU General       #|,
qq|#   Public License for more details.                     #|,
qq|#                                                        #|,
qq|#   You should have received a copy of the GNU General   #|,
qq|#   Public License along with this program; if not,      #|,
qq|#   write to the Free Software Foundation, Inc., 675     #|,
qq|#   Mass Ave, Cambridge, MA 02139, USA.                  #|,
qq|#                                                        #|,
qq|#   You may contact the author, Pat Deegan,              #|,
qq|#   at http://www.psychogenic.com                        #|,
qq|#                                                        #|,
qq|##########################################################|,
);


=head1 NAME

xVOCP - Local message retrieval GUI

=head1 AUTHOR INFORMATION

LICENSE

    xVOCP message retrieval GUI, part of the VOCP voice messaging system.
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



use FileHandle;

############## Tk Libs #############
use Tk 8.0;
use Tk::widgets ;
use Tk::Dialog;
use Tk::DialogBox;
use Tk::LabEntry;
use Tk::Image;
use Tk::Pixmap;
use Tk::JPEG;




use VOCP;
use VOCP::Util;
use VOCP::Device::Local;
use VOCP::Vars;
use VOCP::Strings;
use VOCP::PipeHandle;


use lib '/usr/local/vocp/lib';
#use lib '../lib';
use XVOCP;

use strict;

################################ CONFIGURATION VARIABLES ##########################################



# The location of the VOCP config files (boxes.conf and vocp.conf)
my $BoxConfigFile = $VOCP::Vars::DefaultConfigFiles{'boxconfig'};
my $GenConfigFile = $VOCP::Vars::DefaultConfigFiles{'genconfig'};



use vars qw {
	$Debug
	$Version
	%Strings
	$SupportedLangs
	$Lang
	$Vocp
	$TmpDir
	$DisableSounds
	%AvailBoxes
	$SelectedBox
	$MW
	$Self
	%menubutton_colors
	%button_colors
	%scrollbar_attribs
	%listbox_attribs
	%label_attribs
	%ImageCoords
	$VocpLocalDir
	%AudioConMsg
	};
	

############################ END CONFIGURATION ############################################
$VocpLocalDir = $VOCP::Vars::Defaults{'vocplocaldir'} || '/usr/local/vocp';

#my $DontDeleteFromEnv = 'DISPLAY|TERM|USER|HOSTNAME';
#foreach my $key (keys %ENV)
#{
#	delete $ENV{$key} unless ($key =~ m|^$DontDeleteFromEnv$|o);
#}

$ENV{'PATH'} = "/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin:$VocpLocalDir/bin";


# You can set the interface's default language to either 'en' or 'fr'
my $DefaultLang = 'en';

$Debug = 0; #Set > 0 for more verbose logging, >1 for very verbose

$SupportedLangs =  'en|fr';

$Version = '1.2';



%Strings = (
		'en' => {
				'aboutblurb'	=> "About xvocp\n\nVOCP messaging interface\n\n"
							."(C) 2002 Pat Deegan (www.psychogenic.com)\n\nwww.VOCPsystem.com",
				'versionblurb'	=> "xvocp version $Version",
		},
	
			
		'fr'	=> {	
				'aboutblurb'	=> "A propos de xvocp\n\nInterface de messagerie VOCP\n\n"
							."(C) 2002 Pat Deegan (www.psychogenic.com)\n\nwww.VOCPsystem.com",
				'versionblurb'	=> "xvocp version $Version",
		},
	);
	
$DisableSounds = 0; # Set to 1 to disable sound fx, 0 otherwise

################################ END CONFIG VARIABLES ##########################################


%AudioConMsg = (
			'STOP'	=> 1,
			'PLAYLIN'	=> 2,
			'PLAYRMD'	=> 3,
			'SHUTDOWN' => 4,
		);


# Get, validate and untaint current language
$Lang = shift @ARGV || $DefaultLang;
die "Unsupported language '$Lang'" unless ($Lang =~ m|^($SupportedLangs)$|);
$Lang = $1; 



{

	my $options = {
		'genconfig'	=> $GenConfigFile,
		'boxconfig'	=> $BoxConfigFile,
		'voice_device_type'	=> 'local',
		'voice_device_params'	=> {
						'readnumcallback' => sub { return 1; },
						'device'	=> '/dev/dsp',
						'buffer'	=> 4096,
						'channels'	=> 1,
						'rate'		=> 8000,
					},
		'nocalllog'	=> 1, # no need for logging here...
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck		
		};
	
	$Self = {};
	
	
	bless $Self;
	
	$Vocp = VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP object");
		
	#We connect to the voicedevice
	$Vocp->connect()
		|| VOCP::Util::error("Unable to Initialize");
	
	$TmpDir =  $Vocp->{'tempdir'} || $VOCP::Vars::Defaults{'tempdir'} || '/tmp';
	unless ($TmpDir && -w  $TmpDir)
	{
		print STDERR "Can't write to $TmpDir\n"
			if ($Debug);
		$TmpDir = (getpwuid($>))[7] ; 
		unless ( -w $TmpDir)
		{
			print STDERR "Can't write to $TmpDir either - aborting.\n";
			exit (1);
		}
	}
	chdir($TmpDir);
	
	$Self->{'_currentDir'} = $TmpDir;
	print "\n\n$License\n";
	
	my ($readFh, $writeFh) = FileHandle::pipe;
	$readFh->autoflush();
	$writeFh->autoflush();
	
	$Self->{'_readbits'} = '';
	vec($Self->{'_readbits'}, $readFh->fileno(), 1) = 1;
	
	$Self->{'_readFh'} = $readFh;
	$Self->{'_writeFh'} = $writeFh;
	
	
	
	my $child = fork();
	if ($child)
	{
		# in parent
		close($readFh);
		#$SIG{CHLD} = \&REAPER; # can't use a reaper with vocp::pipehandles or system calls
		$SIG{TERM} = \&quit;

		$Self->{'_childpid'} = $child;
		
	} else {
	
		close($writeFh);
		audioPipeReader($Self);
		exit(0);
	}
	
	
	
	init();
	
	$Self->{'windowGen'} =  XVOCP::WindowGenerator->new(	'parent'	=> $MW,
						);
						
	$Self->{'dialogFactory'} = XVOCP::DialogFactory->new();
	
	my @boxes = sort keys (%AvailBoxes);
	#$MW->raise(); -- causing display troubles with message list box?
	# wanted to use it to ensure the password window appears on top...
	$MW->update();
	if (scalar @boxes == 1)
	{
		selectMailBox($boxes[0]);
	}
	
	MainLoop();
	
	quit();
}



sub audioPipeWriter {
	my $self = shift;
	my $message = shift || return;
	my $arg = shift || '';
	
	print STDERR "audioPipeWriter called with args '$self', '$message', '$arg'\n" if ($Debug);
	
	my $writeFh = $self->{'_writeFh'};
	
	#print $writeFh "$message\n";
	return unless ($writeFh && $writeFh->opened());
	syswrite($writeFh, "$message\n");
	print STDERR "Sending message '$message' to audio pipe reader.\n" if ($Debug);
	if ($arg)
	{
		
		my $arglen = length($arg) + 1;
		
		my $arglenLen = length($arglen);
		if ($arglenLen < 4)
		{
			my $ostring = '0' x (4 - $arglenLen);
			$arglen =   "$ostring$arglen";
			#my $tosendlen = "$arglen\n";
			
		} elsif ($arglenLen > 4)
		{
			die " Argument too long '$arglen'";
		}
		
		syswrite($writeFh, "$arglen\n");
		print STDERR "Sending arglen '$arglen' to audio pipe reader.\n" if ($Debug);
		#print $writeFh "$arg\n";
		syswrite($writeFh, "$arg\n");
		print STDERR "Sending arg '$arg' to audio pipe reader.\n" if ($Debug);
		
	}
	
	return;
}


sub StopNow {

	
	$Vocp->{'voicedevice'}->stop();
	
	$SIG{USR2} = \&StopNow;
}

sub audioPipeReader {
	my $self = shift;
	
	$SIG{USR2} = \&StopNow;
	print STDERR "audioPipeReader() started...\n" if ($Debug);
	
	my $cont = 1;
	do {
		if (dataWaiting($self))
		{
			my $readFh = $self->{'_readFh'};
	
			my ($type, $argsize, $arg);
			sysread($readFh, $type, 2);
			chomp($type);
			
			print STDERR "Audiopipe reader got message of type '$type'\n" if ($Debug);
			if ($type)
			{
				if ($type == $AudioConMsg{'SHUTDOWN'})
				{
					print STDERR "GOT SHUTDOWN>>>>>>\n";
					$cont = 0;
					$Vocp->disconnect();
				} elsif ($type == $AudioConMsg{'STOP'})
				{
					
					$Vocp->{'voicedevice'}->stop();
				} elsif ($type == $AudioConMsg{'PLAYLIN'} || $type == $AudioConMsg{'PLAYRMD'})
				{
					sysread($readFh, $argsize, 5);
					chomp($argsize);
					sysread($readFh, $arg, $argsize);
					chomp($arg);
					print STDERR "Audiopipe reader got arg size '$argsize' for arg '$arg'\n" if ($Debug);
					my $ftype  = ($type == $AudioConMsg{'PLAYLIN'} ? 'lin' : 'rmd');
					
					$Vocp->{'voicedevice'}->play($arg, $ftype);
				} else {
					print STDERR "Unrecognized AudioConMsg '$type'\n";
				}
			} else {
				print STDERR "Audiopipe received a message with no type - exiting" if ($Debug);
				$cont = 0;
			}
				
		}
	} while ($cont);
	
	return;
}


sub dataWaiting {
	my $self = shift;
	
	my $rbits;
	
	my $nfound = select($rbits = $self->{'_readbits'},undef,undef,0.3); 
	
	print STDERR "Data waiting: '$nfound'\n" if ($Debug > 1);
	return undef if ($nfound == 0);
	
	return 1;
}



sub playLin {
	my $file = shift || return;
	my $sync = shift;
	#$Self->{'stoppedPlay'} = 0;
	#$Vocp->{'voicedevice'}->play($file, 'lin', $sync);
	
	print STDERR "Calling audioPipeWriter($AudioConMsg{'PLAYLIN'}, $file)\n" if ($Debug);
	
	$Self->audioPipeWriter($AudioConMsg{'PLAYLIN'}, $file);
}

sub playRmd {
	my $file = shift || return;
	my $sync = shift;
	
	#$Self->{'stoppedPlay'} = 0;
	#$Vocp->{'voicedevice'}->play($file, 'rmd', $sync);
	print STDERR "Calling audioPipeWriter($AudioConMsg{'PLAYRMD'}, $file)\n" if ($Debug);
	
	$Self->audioPipeWriter($AudioConMsg{'PLAYRMD'}, $file);

}

sub soundEffect {
	my $type = shift || 'click';
	my $sync = shift;
	
	return undef if ($DisableSounds);
	
	my $file = $VOCP::Device::Local::SoundFiles{$type};
	
	return undef unless ($file);
	
	playLin($file, $sync);
	
	return;
}




sub init {

	my $user = (getpwuid($<))[0];
	
	while (my ($boxnum, $boxObj) = each %{$Vocp->{'boxes'}})
	{
		next unless ($boxObj);
		my $owner = $boxObj->owner();
		if ( $owner && $owner eq $user )
		{
			my $boxtype = $boxObj->type();
			if ($boxtype && $boxtype eq 'mail')
			{
				$AvailBoxes{$boxnum} = $boxObj;
			}
		}
		
	}

	
	init_colors();	
	$MW = new_mainwindow();
	build_menubar();
	
}

sub selectMailBox {
	my $number = shift;
	
	return undef unless ($number && $number =~ /\d+/);
	
	VOCP::Util::error("selectMailBox passed an invalid box number: '$number'")
		unless ($number =~ m|^(\d+)$|);
	
	$number = $1; #untaint
	
	VOCP::Util::log_msg("selectMailBox: $number")
		if ($Debug);
	
	VOCP::Util::error("selectMailBox() Unavailable box '$number' selected.")
		unless (exists $AvailBoxes{$number} && $AvailBoxes{$number});
	
	
	unless ($Self->{'passwords'}->{$number} && $Vocp->check_password($number,$Self->{'passwords'}->{$number}) )
	{
		
	
		my $popup = $Self->{'windowGen'}->newWindow(		'type'	=> 'confirm',
							'name'	=> 'fetchpass',
							'modal'	=> 1,
							'title'	=> 'Enter Password for box ' . $number,
							'parent' => $MW,
					);
	
		$Self->{'passwords'}->{$number} = '';
		my $labelEntry = $popup->LabEntry(-label => "Password: ",
	     				-labelPack => [-side => "left", -expand => 0],
	     				-width => 10,
					-relief => 'groove',
					-show=>'*',
	     				-textvariable => \$Self->{'passwords'}->{$number},
	     			%XVOCP::Colors::labentryLight_attribs)->place(-x => 70, -y=> 60); 
  		$labelEntry->focus();
  		

		$Self->{'windowGen'}->show('fetchpass');
		
		my $resp = $Self->{'windowGen'}->action();
		
		unless ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'})
		{
			delete $Self->{'passwords'}->{$number};
			return;
		}
		
		
		
		return errorBox($MW, "Invalid password for box $number") 
				unless ($Vocp->check_password($number,$Self->{'passwords'}->{$number}));
	}
		
	$SelectedBox = $number;
	
	refreshMessageListBox($number);
	
}


sub playMessage {
	my $junk = shift;
	my $sync = shift;
	
	my $msg = getSelectedMessageObject() || return undef;
	
	my $file = $msg->filename();
	
	VOCP::Util::log_msg("playMessage: About to play file '$file'")
		if ($Debug);
	
	playRmd($file, $sync);
	
	
	
}



sub playAllMessages {

	soundEffect('tick');
	
	my $numElements = $Self->{'messageListbox'}->size();
	
	print STDERR "playAllMessages() $numElements in listbox\n" if ($Debug);
	
	return undef unless ($numElements);
	 
	my $selectedIdx = $Self->{'messageListbox'}->curselection() || 0;
	$Self->{'messageListbox'}->activate($selectedIdx);
	
	my @messagesToPlay = ($selectedIdx .. $numElements);
	$Self->{'stoppedPlay'} = 0;

	foreach my $msgIdx (@messagesToPlay)
	{
		print STDERR "playAllMessages() playing msg idx $msgIdx\n" if ($Debug);
	
		return if ($Self->{'stoppedPlay'});
		$Self->{'messageListbox'}->selectionClear(0,'end');
		$Self->{'messageListbox'}->activate($msgIdx);
		$Self->{'messageListbox'}->selectionSet($msgIdx, $msgIdx);
		playMessage();
		$MW->update();
	}
		
	return ;
}

sub forwardMessage {
	my $msg = getSelectedMessageObject() || return undef;
	
	my $forwardWin = new_forward();
	
}

sub exportMessage {
	my $msg = getSelectedMessageObject() || return undef;
	
	return undef unless ($msg);
	
	my $filename = $msg->filename();
	my $name = $filename;
	unless ($name =~ m|/([^/]+)$|)
	{
		VOCP::Util::error("exportMessage() Strange filename for message '$name'");
	}
	
	$name = $1; # untaint
	
	$name =~ s/\.\w{1,4}$//g;
	
	soundEffect('woosh');
	
	my $selectedFile = $Self->{'windowGen'}->selectFile($MW, $Self->{'_currentDir'});
	
	soundEffect('tick');

	return undef unless ($selectedFile);
	
	if ($selectedFile =~ m|^(/.*/)[^/]+$|)
	{
		$Self->{'_currentDir'} = $1;
	}
	
	unless ($selectedFile =~ m|[^/]+\.([\w\d]{2,4})$|)
	{
		return errorBox($MW, "You must specify an extension (.ogg .mp3 .wav) to export");
	}
	
	my $encoding = $1;
	
	unless ($encoding =~ m!^(ogg|mp3|wav|pvf)$!)
	{
		return errorBox($MW, "Unknown encoding '$encoding'. Please use ogg/mp3/wav.");
	}
	
	my $newName = $selectedFile;
	if (-e $newName)
	{
		return undef if (confirmBox($MW, "File $newName exists. Overwrite?") != $XVOCP::WindowGenerator::Action{'CONFIRM'});
	}
	
	
	my $output = $Vocp->create_attachment($filename, $encoding) 
			|| return errorBox($MW, "Returned attachement $encoding was empty.");
	
	my $outputFile = FileHandle->new();
	
	unless ($outputFile->open(">$newName"))
	{
		return errorBox($MW, "Can't seem to open $newName for write: $!");
	}
	
	$outputFile->print($output);
	$outputFile->close();
	
	
}

sub stopPlay {
	
	$Self->{'stoppedPlay'} = 1;
	#$Vocp->{'voicedevice'}->stop();
	my $child = $Self->{'_childpid'};
	if ($child)
	{
		kill 12, $child;
	}
	#$Self->audioPipeWriter($AudioConMsg{'STOP'});
}

sub deleteMessage {
	my $msg = getSelectedMessageObject() || return undef;
	
	my $num = $msg->number();
	my $resp = confirmBox($MW, "Are you sure you wish to delete message $num", "Really delete?");
	
	print STDERR "Delete confirm response is: $resp\n" if ($Debug);
	
	
	unless ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'})
	{
		return undef;
	}
	$AvailBoxes{$SelectedBox}->deleteMessageByID($msg->number());
	
	
	refreshMessageListBox();
	
}


sub confirmBox {
	my $parentWindow = shift;
	my $message = shift;
	my $title = shift || 'Confirm';
	
	VOCP::Util::log_msg("confirmBox() Called with message '$message'")
		if ($Debug);
	
	
	my $winName = 'confirm';
	my $popup = $Self->{'windowGen'}->newWindow(	'type'	=> 'confirm',
							'name'	=> $winName,
							'modal'	=> 1,
							'title'	=> $title,
							
					);
	$message =~ s/(.{20,30})\s/$1\n/g;
	$message =~ s/\n\s+/\n/g;
	
	$popup->Label(-text => $message,
			%XVOCP::Colors::labelInv_attribs)->place(
						-x => 85,
						-y => 55,
					);
	my $titleImg = $popup->Photo('conf_title', -file => $XVOCP::Images{'confirmtitle'},-format => 'jpeg');
	$popup->Label(-image => $titleImg, -bg =>  $XVOCP::Colors::DefUIAttrib{'backgroundLight'})->place(	-x => '123',
								-y => '11',
							);
	
	$Self->{'windowGen'}->show($winName);
	
	
	
	my $resp = $Self->{'windowGen'}->action();
	
	resetImages();
	return $resp;

	
}


sub help {

	
	$Self->{'windowGen'}->helpWindow(
							'modal'	=> 0,
							'title'	=> "Help",
							'file' =>"$VocpLocalDir/doc/xvocp.txt",
							'forceuntaint'	=> 1,
							
					);

	return;
}



sub version {

	
	$Self->{'windowGen'}->versionWindow(
							'modal'	=> 1,
							'title'	=> 'xVOCP version',
							'text' =>  $Strings{$Lang}{'versionblurb'},
							
					);

	return;
}

sub about {

	
 	$Self->{'windowGen'}->newWindow(			'type'	=> 'about',
								'name'	=> 'about',
								'modal'	=> 1,
								'title'	=> "About xVOCP",
					);
	$Self->{'windowGen'}->show('about');				


	return;
}


sub toggleEmail2Vm {
	
	return unless ($SelectedBox);
	
	return unless ($Self && defined $Self->{'passwords'}->{$SelectedBox});
	
	my $command = $VOCP::Vars::Defaults{'vocplocaldir'} . '/bin/toggleEmail2Vm.pl';
	
	return errorBox($MW, "Can't find an executable '$command'")
		unless (-e $command && -x $command);
	
	$command .= qq! "$SelectedBox*$Self->{'passwords'}->{$SelectedBox}" |!;
	
	my $commandHandle = VOCP::PipeHandle->new();
	
	unless ($commandHandle->open($command))
	{
		return errorBox($MW, "Could not open command. Aborting.");
	}
	
	my $output = join("\n", $commandHandle->getlines());
	
	$commandHandle->close();
	
	return infoBox($MW, $output, "Done");
	
}
		
		
	 
	
sub quit {
	
	print STDERR "In quit()\n" if ($Debug);
	return unless ($Self->{'_childpid'});
	unless ($Self->{'quat'})
	{
	
		#stopPlay() if ($Self->{'_childpid'});
		
		$Self->audioPipeWriter($AudioConMsg{'SHUTDOWN'});
		if ($Self->{'_childpid'})
		{
			print STDERR "Killing : " . $Self->{'_childpid'} . "\n" if ($Debug);
			kill 15, $Self->{'_childpid'};
			
		}
		$Self->{'quat'} = 1;
		
	}
		
	
	exit(0);
}





#### Privates ####

sub getSelectedMessageObject {
	my $selected = $Self->{'messageListbox'}->get('active');

	return undef unless ($selected);
	
	VOCP::Util::log_msg("getSelectedMessageObject: Selected message '$selected'")
		if ($Debug > 1);
	
	if ($selected !~ m|^\s*(\d+)\s|)
	{
		VOCP::Util::error("getSelectedMessageObject: Selected message '$selected' has invalid format.");
	}
	my $num = $1;
	
	VOCP::Util::error("getSelectedMessageObject: No message found in cache matching '$selected'")
		unless (exists $Self->{'messageCache'}->{$num} && $Self->{'messageCache'}->{$num});
	
	return  $Self->{'messageCache'}->{$num};
}


sub init_colors {
	
	%menubutton_colors = %XVOCP::Colors::menubutton_colors;

	%button_colors = %XVOCP::Colors::button_colors;


	%scrollbar_attribs = %XVOCP::Colors::scrollbar_attribs;
	
	%listbox_attribs = %XVOCP::Colors::listbox_attribs;
	
	%label_attribs = %XVOCP::Colors::label_attribs;

	
	%ImageCoords = (
			1	=> {
					'x'	=> 86,
					'y'	=> 259,
					'name'	=> '01.jpg',
					'mouseover'	=> '01_over.jpg',
					'method'=> sub { soundEffect('tick'); refreshMessageListBox() } ,
				},
			2	=> {
					'x'	=> 139,
					'y'	=> 259,
					'name'	=> '02.jpg',
					'mouseover'	=> '02_over.jpg',
					'method'=> sub { stopPlay() ; soundEffect('tick'); } ,
				},
			3	=> {
					'x'	=> 195,
					'y'	=> 259,
					'name'	=> '03.jpg',
					'mouseover'	=> '03_over.jpg',
					'method'=> sub { stopPlay() ;  soundEffect('tick'); playMessage() },
				},
			4	=> {
					'x'	=> 240,
					'y'	=> 259,
					'name'	=> '04.jpg',
					'mouseover'	=> '04_over.jpg',
					'method'=> sub { soundEffect('tick'); playAllMessages() },
				},
			5	=> {
					'x'	=> 290,
					'y'	=> 259,
					'name'	=> '05.jpg',
					'mouseover'	=> '05_over.jpg',
					'method'=> sub { soundEffect('tick'); forwardMessage() },
				},
			6	=> {
					'x'	=> 339,
					'y'	=> 259,
					'name'	=> '06.jpg',
					'mouseover'	=> '06_over.jpg',
					'method'=> sub { soundEffect('tick'); deleteMessage() },
				},
			7	=> {
					'x'	=> 42,
					'y'	=> 17,
					'name'	=> 'player_number.jpg',
				},
			8	=> {
					'x'	=> 107,
					'y'	=> 17,
					'name'	=> 'player_date.jpg',
				},
			9	=> {
					'x'	=> 234,
					'y'	=> 17,
					'name'	=> 'player_from.jpg',
				},
			10	=> {
					'x'	=> 369,
					'y'	=> 17,
					'name'	=> 'player_size.jpg',
				},
	);
}



sub refreshMessageListBox {
	my $number = shift || $SelectedBox;
	
	
	return undef unless ($number && $number =~ /^\d+$/);
	
	VOCP::Util::log_msg("refreshMessageListBox: $number")
		if ($Debug);
	
	VOCP::Util::error("selectMailBox() Unavailable box '$number' selected.")
		unless (exists $AvailBoxes{$number} && $AvailBoxes{$number});
	
	my $messages = $AvailBoxes{$number}->listMessages('INVDATE', 'FORCEREFRESH');
	
	my $metaData =  $AvailBoxes{$number}->metaData();
	
	delete $Self->{'messageCache'};
	my @msgList;
	foreach my $msg (@{$messages})
	{
		my $details = $msg->getDetails();
		my $messageData = $metaData->messageData($details->{'number'});
		my $num = $details->{'number'};
		
		next unless (defined $num);
		
		my $unixtime = $messageData->attrib('time') || $details->{'time'};
		
		my $timedate = ($unixtime && $unixtime != 1) ? localtime($unixtime) : 'Unknown';
		$timedate =~ s/^(\w+\s+.+\d+:\d+):\d+\s+\d+/$1/;
		my $size = $messageData->attrib('size') || $details->{'size'} || '0';
		
		my $from = $messageData->attrib('from') ;
		
		# Prepare a String
		#NUM    DATETIME            SIZE
		
		my $spaces = 9 - length("$num") ;
		$spaces = 1 unless ($spaces > 0);
		my $spStr = ' ' x $spaces;
		my $dispStr = "$num" . $spStr . $timedate;
		
		if ($from && $from ne 'none')
		{
			my $dispFrom ;
			if ($from =~ m|(\S\@\S\.\S)|)
			{
				$dispFrom = $1;
			} else {
				$dispFrom = $from;
			}
			
			$dispFrom =~ s/\s\s+/ /;
			
			$dispFrom = substr($dispFrom, 0, 17); 
			$spaces = 37 - length("$dispStr") - length("$dispFrom") - 1;
			$spaces = 1 unless ($spaces > 0);
			$spStr = ' ' x $spaces;
			
			$dispStr .= "$spStr $dispFrom";
		
		}
		
		$spaces = 52 - length("$dispStr") - length("$size") - 1;
		$spaces = 1 unless ($spaces > 0);
		$spStr = ' ' x $spaces;
		$dispStr .= "$spStr $size";
		
		VOCP::Util::log_msg("refreshMessageListBox: Adding string '$dispStr' to message list")
			if ($Debug > 1);
	
		$Self->{'messageCache'}->{$num} = $msg;
		push @msgList, $dispStr;
		
		
	}
	
	# or
	$Self->{'messageListbox'}->delete(0,'end');
	$Self->{'messageListbox'}->insert(0, @msgList);
	$Self->{'messageListbox'}->selectionClear(0,'end');
	$Self->{'messageListbox'}->see(0);
	$Self->{'messageListbox'}->activate(0);
	$Self->{'messageListbox'}->selectionSet(0);
	
	$MW->raise();
	return scalar @msgList;
	
	
}

sub resetImages {
	
	for(my $i=1; $i<=6; $i++)
	{
		changeImage($i, 'off');
	}
}

sub changeImage {
	my $number = shift;
	my $state = shift;
	
	my $imgname = "image0$number";
	if ($state eq 'on') 
	{
		$imgname .= 'rollover';
	}
	 
	VOCP::Util::error("changeImage() No such image '$imgname'")
		unless ($Self->{'images'}->{$imgname});
	$Self->{'buttons'}->{$number}->configure(-image => $Self->{'images'}->{$imgname});
}


sub errorBox {
	my $parentWin = shift || $MW;
	my $message = shift;
	my $title = shift || "Error";
	
	#$Self->{'dialogFactory'}->errorBox($MW, $message, $title);
	$Self->{'windowGen'}->errorWindow(
						'modal'	=> 1,
						'title'	=> $title,
						'parent' => $parentWin,
						'text'	=> $message,
				);
	
	print STDERR "$message\n" if ($Debug);
}



sub infoBox {
	my $parentWin = shift || $MW;
	my $message = shift;
	my $title = shift || "Error";
	
	#$Self->{'dialogFactory'}->errorBox($MW, $message, $title);
	$Self->{'windowGen'}->infoWindow(
						'modal'	=> 1,
						'title'	=> $title,
						'parent' => $parentWin,
						'text'	=> $message,
				);
	
	print STDERR "$message\n" if ($Debug);
}


sub FwdSend {
	
	
	#my $selMsg = $MessageList->get('active');
	#return undef unless (defined $selMsg);
	my $msg = getSelectedMessageObject() || return undef;
	
	my $messageFile = $msg->filename();
	
	my $username = (getpwuid($>))[0];
	my $attachmentFormat = $Self->{'forward'}->{'encoding'};
	my $text = $Self->{'forward'}->{'Text'}->get('1.0','end') || "VOCP message forwarded by $username" ;
	my $subject = "VOCP message forwarded by $username";
	my $from = $Self->{'forward'}->{'from'};
	my $to = $Self->{'forward'}->{'to'};
	
	
	$Self->{'forwardWindow'}->destroy();
	delete $Self->{'forwardWindow'};
	
	return errorBox($MW, "Must include a From for forwarded message") unless ($from);
	return errorBox($MW, "Must include a recipient (To:) for forwarded message") unless ($to);
	return errorBox($MW, "Must specify encoding for forwarded attachement.") unless ($attachmentFormat);
	
	
	return errorBox($MW, "Invalid 'to' specified ($to)") unless ($to =~ m|^[\w\d\._\@-]+$|);
	return errorBox($MW, "Invalid 'from' specified ($from)") unless ($from =~ m|^[\w\d\._\@\s"<>-]+$|); #"
	
	soundEffect('tick');
	my $attach = $Vocp->create_attachment($messageFile, $attachmentFormat, 'BASE64ENCODE');
	
	my $email = VOCP::Util::create_email($from, $to, $subject, $text, $attach, $attachmentFormat);
		
	open (MAIL, "| $Vocp->{'programs'}->{'email'} $to")
		|| VOCP::Util::error("Can't open $Vocp->{'programs'}->{'email'} for write: $!");
	
	print MAIL $email;
	
	close (MAIL);
	
	errorBox($MW, "Message sent.", 'Forward success.');
	
}
	







##################################################################################################
############################              tk window creation               #######################
##################################################################################################

sub new_mainwindow {
	my $temp_win = new MainWindow(-title=>'xVOCP 1.0',
					-background => '#09557B',
					-borderwidth => 0,
					-relief => 'flat',
					-height => 343,
					-width => 456);
	$temp_win->iconname('xvocp');
	my $xpm = $temp_win->Photo('xvocp');
	$xpm->read("$VocpLocalDir/images/xvocp.xpm");
	$temp_win->iconimage($xpm);
	
	$temp_win->configure( %label_attribs);	
	$temp_win->geometry("456x344");
	my $bgimage = $temp_win->Photo('bgimage', -file => $VocpLocalDir . '/images/xvocp/player.jpg', -format => 'jpeg');
	my $imglabel = $temp_win->Label(-image => $bgimage, -bg => '#09557B')->place(
						-x => 0,
						-y => 0,
					);
	
					
	$Self->{'messageListbox'} = $temp_win->Scrolled('Listbox', 
		-width => '52',
		-height => '11',
		-font => 'fixed -12',
		-scrollbars => 'e',
		-relief => 'flat',
		%listbox_attribs,
	)->place(
		-x => '42',
		-y => '42',
	);
	
	
			
	for (my $i = 1; $i <=10; $i++)
	{
		my $imgname = "image0$i";
		$Self->{'images'}->{$imgname} = 
					$temp_win->Photo($imgname, -file => "$VocpLocalDir/images/xvocp/".$ImageCoords{$i}{'name'}, 
								-format => 'jpeg');
					
		$Self->{'buttons'}->{$i} = $temp_win->Label(-image => $Self->{'images'}->{$imgname}, 
							-borderwidth => 0, -takefocus => 1, -bg => '#09557B')->place(
							-x => $ImageCoords{$i}{'x'},
							-y => $ImageCoords{$i}{'y'},
					);
		
		$Self->{'buttons'}->{$i}->bind('<ButtonRelease-1>', $ImageCoords{$i}{'method'}) if ($ImageCoords{$i}{'method'});
		$Self->{'buttons'}->{$i}->bind('<Return>', $ImageCoords{$i}{'method'}) if ($ImageCoords{$i}{'method'});
		if ($ImageCoords{$i}{'mouseover'})
		{
			$imgname .= 'rollover';
			$Self->{'images'}->{$imgname} = 
				$temp_win->Photo($imgname, -file => "$VocpLocalDir/images/xvocp/".$ImageCoords{$i}{'mouseover'},
							 -format => 'jpeg');
		}
					
		
		
	}
	
	# Set up rollovers for our main buttons
	
	$Self->{'buttons'}->{1}->bind('<Enter>', sub { changeImage(1 , 'on');});	
	$Self->{'buttons'}->{1}->bind('<Leave>', sub { changeImage(1, 'off');});
	
	$Self->{'buttons'}->{2}->bind('<Enter>', sub { changeImage(2 , 'on');});	
	$Self->{'buttons'}->{2}->bind('<Leave>', sub { changeImage(2, 'off');});
	
	$Self->{'buttons'}->{3}->bind('<Enter>', sub { changeImage(3 , 'on');});	
	$Self->{'buttons'}->{3}->bind('<Leave>', sub { changeImage(3, 'off');});
	
	$Self->{'buttons'}->{4}->bind('<Enter>', sub { changeImage(4 , 'on');});	
	$Self->{'buttons'}->{4}->bind('<Leave>', sub { changeImage(4, 'off');});
	
	$Self->{'buttons'}->{5}->bind('<Enter>', sub { changeImage(5 , 'on');});	
	$Self->{'buttons'}->{5}->bind('<Leave>', sub { changeImage(5, 'off');});
	
	$Self->{'buttons'}->{6}->bind('<Enter>', sub { changeImage(6 , 'on');});	
	$Self->{'buttons'}->{6}->bind('<Leave>', sub { changeImage(6, 'off');});
	
	
	
	
	#FocusIn, FocusOut
	$Self->{'buttons'}->{1}->bind('<FocusIn>', sub { changeImage(1 , 'on');});	
	$Self->{'buttons'}->{1}->bind('<FocusOut>', sub { changeImage(1, 'off');});
	
	
	$Self->{'buttons'}->{2}->bind('<FocusIn>', sub { changeImage(2 , 'on');});	
	$Self->{'buttons'}->{2}->bind('<FocusOut>', sub { changeImage(2, 'off');});
	
	$Self->{'buttons'}->{3}->bind('<FocusIn>', sub { changeImage(3 , 'on');});	
	$Self->{'buttons'}->{3}->bind('<FocusOut>', sub { changeImage(3, 'off');});
	
	$Self->{'buttons'}->{4}->bind('<FocusIn>', sub { changeImage(4 , 'on');});	
	$Self->{'buttons'}->{4}->bind('<FocusOut>', sub { changeImage(4, 'off');});
	
	$Self->{'buttons'}->{5}->bind('<FocusIn>', sub { changeImage(5 , 'on');});	
	$Self->{'buttons'}->{5}->bind('<FocusOut>', sub { changeImage(5, 'off');});
	
	$Self->{'buttons'}->{6}->bind('<FocusIn>', sub { changeImage(6 , 'on');});	
	$Self->{'buttons'}->{6}->bind('<FocusOut>', sub { changeImage(6, 'off');});
	
	
	
	
	$Self->{'messageListbox'}->bind('<Double-1>' => \&playMessage);
	$Self->{'messageListbox'}->Subwidget('xscrollbar')->configure(-relief => 'flat',-borderwidth =>1, -highlightthickness => 0, %scrollbar_attribs);
	$Self->{'messageListbox'}->Subwidget('yscrollbar')->configure(-relief => 'flat', -borderwidth =>1, -highlightthickness => 0, %scrollbar_attribs);
	$Self->{'messageListbox'}->Subwidget('corner')->configure(-relief => 'flat', %label_attribs);
	
	return $temp_win;
}


#-------------------------------------------------------------
#  Creates and returns the menubar widget.
#  Called from init at startup
#------------------------------------------------------------
sub build_menubar {
	

	my $menubar = $MW->Menu(-type => 'menubar', -relief => 'flat', -activeborderwidth => 0, 
				-foreground => '#FF0000', -background => '#FF0000',
				-disabledforeground => '#FF0000', -activeforeground => '#FF0000',
				 -activebackground => '#FF0000',  %menubutton_colors
				#-background => '#00566F',
				#-activebackground => '#0A6179');
			);
	$MW->configure(-menu=>$menubar );

	## file menu
	my $box=$menubar->cascade(-label =>'~'. $VOCP::Strings::Strings{$Lang}{'box'} || 'box' , -tearoff =>0, %menubutton_colors);
	
	$box->menu->configure( %menubutton_colors);
	
	my $count = 0;
	
	foreach my $boxnum (sort keys %AvailBoxes)
	{
		$count++;
		$box->command(-label => '~' . "$boxnum" , %menubutton_colors,
			-command => sub { selectMailBox($boxnum); });
		
	}
	
	unless ($count)
	{
		$box->command(-label => $VOCP::Strings::Strings{$Lang}{'noboxes'} || 'noboxes' ,  %menubutton_colors,
			-command => sub { return 1; });
	}
	my $separator = $box->separator();
	
	#$separator->configure(-background => '#156187', -foreground => '#55A1C7');
	$box->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'toggleEmail2Vm'}  || 'toggleEmail2Vm') ,  %menubutton_colors,
			-command => \&toggleEmail2Vm);

	$box->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'quit'}  || 'quit') ,  %menubutton_colors,
			-command => \&quit);

	my $message=$menubar->cascade(-label =>'~'.$VOCP::Strings::Strings{$Lang}{'message'} || 'message' , 
					-tearoff =>0,%menubutton_colors);
	$message->menu->configure( %menubutton_colors);
	
	$message->command(-label => $VOCP::Strings::Strings{$Lang}{'play'} || 'play'  ,  %menubutton_colors,
			-command => \&playMessage);
			
	$message->command(-label => $VOCP::Strings::Strings{$Lang}{'stop'} || 'stop'  ,  %menubutton_colors,
			-command => \&stopPlay);
	
	
	$message->command(-label => $VOCP::Strings::Strings{$Lang}{'export'} || 'export' ,  %menubutton_colors,
			-command => \&exportMessage);
	$message->command(-label => $VOCP::Strings::Strings{$Lang}{'forward'} || 'fwd' ,  %menubutton_colors,
			-command => \&forwardMessage);
	
	$message->separator();
	$message->command(-label => $VOCP::Strings::Strings{$Lang}{'delete'}  || 'delete' ,  %menubutton_colors,
			-command => \&deleteMessage);
	
	## help menu
	my $help=$menubar->cascade(-label =>'~'.$VOCP::Strings::Strings{$Lang}{'help'}  || 'help', 
					-tearoff =>0,%menubutton_colors);
	$help->menu->configure( %menubutton_colors);
	$help->command(-label => "~$VOCP::Strings::Strings{$Lang}{'help'}...",%menubutton_colors,
			-command => \&help
			);
	$help->separator();
	
	$help->command(-label => $VOCP::Strings::Strings{$Lang}{'version'},
			-command => \&version,
			%menubutton_colors);
	#$help->separator;
	$help->command(-label => $VOCP::Strings::Strings{$Lang}{'about'},
			-command => \&about,
			%menubutton_colors);

	return $menubar	 # return just built menubar

} # end build_menubar




sub new_forward {

	#return undef unless (defined $selMsg);
	my $msg = getSelectedMessageObject() || return undef;
	
	my $messageNum = $msg->number();
	$Self->{'fwdMessage'} = $msg;
	
	my $temp_win = $Self->{'windowGen'}->newWindow(		'type'	=> 'forward',
								'name'	=> 'forward',
								'modal'	=> 1,
								'title'	=> "Forward Message $messageNum",
								'nodestroy'	=> 1,
					);
	
	
	
	my $username = (getpwuid($<))[0];
	my $forward = $temp_win;
	
	delete $Self->{'forward'};
	

	
	my $titleImg = $forward->Photo('forward_title', -file => $XVOCP::Images{'forwardtitle'},-format => 'jpeg');
	$forward->Label(-image => $titleImg, -bg => $XVOCP::Colors::DefUIAttrib{'backgroundLight'})->place(	
								-x => 169,
								-y => 10,
							);
	

	$Self->{'forward'}->{'encoding'} = '';
	my $radiobutton = $forward->Radiobutton(
		-justify => 'left',
		#-text => '',
		-variable => \$Self->{'forward'}->{'encoding'},
		-value => 'ogg',
		%XVOCP::Colors::radiobutton_attribs
	)->place(
		-x => '228',
		-y => '75',
	);
	
	$radiobutton->select();
	my $radiobutton1 = $forward->Radiobutton(
		-justify => 'left',
		#-text => '',
		-variable => \$Self->{'forward'}->{'encoding'},
		-value => 'mp3',
		%XVOCP::Colors::radiobutton_attribs
	)->place(
		-x => '278',
		-y => '75',
	);
	
	my $radiobutton3 = $forward->Radiobutton(
		-justify => 'left',
		#-text => '',
		-variable => \$Self->{'forward'}->{'encoding'},
		-value => 'wav',
		%XVOCP::Colors::radiobutton_attribs
	)->place(
		-x => '331',
		-y => '75',
	);
	my %radioLabels = (
				'ogg'	=> $forward->Photo('l_ogg', -file => $XVOCP::Images{'ogg'}, -format => 'jpeg'),
				'mp3'	=> $forward->Photo('l_mp3', -file => $XVOCP::Images{'mp3'}, -format => 'jpeg'),
				'wav'	=> $forward->Photo('l_wav', -file => $XVOCP::Images{'wav'}, -format => 'jpeg'),
	);
				
	$forward->Label(-image => $radioLabels{'ogg'}, %XVOCP::Colors::label_attribs,
						-bg => $XVOCP::Colors::DefUIAttrib{'textlabelbg'})->place( -x => 244,
												-y => 75);
	
	$forward->Label(-image => $radioLabels{'mp3'}, %XVOCP::Colors::label_attribs,
						-bg => $XVOCP::Colors::DefUIAttrib{'textlabelbg'})->place( -x => 295,
												-y => 75);

	$forward->Label(-image => $radioLabels{'wav'}, %XVOCP::Colors::label_attribs, 
					-bg => $XVOCP::Colors::DefUIAttrib{'textlabelbg'})->place( -x => 350,
												-y => 75);


	$Self->{'forward'}->{'From'} = '';
	my $entry = $forward->Entry(
			-textvariable => \$Self->{'forward'}->{'from'} ,
			-relief => 'flat',
			-font =>'arial -10',
			-width => 23,
			%XVOCP::Colors::listbox_attribs,
			%XVOCP::Colors::textentry_attribs,
			
	)->place(
		-x => '72',
		-y => '51' ,
	);
	
	$Self->{'forward'}->{'from'} = $username;
	
	$Self->{'forward'}->{'To'} = '';
	my $entry1 = $forward->Entry(
			-textvariable => \$Self->{'forward'}->{'to'},
			-font =>'arial -10',
			-width => 23,
			%XVOCP::Colors::listbox_attribs,
			%XVOCP::Colors::textentry_attribs,
	)->place(
		-x => '72',
		-y => '76',
	);
	
	$Self->{'forward'}->{'Text'} = $forward->Text(
			-font => 'arial -10',
			-width => '50',
			-height => '10',
			%XVOCP::Colors::listbox_attribs,
			%XVOCP::Colors::textentry_attribs,
	)->place(
		-x => '72',
		-y => '99',
	);
	

	$Self->{'forwardWindow'} = $forward;
	
	
	soundEffect('woosh');
		
	$Self->{'windowGen'}->show('forward');

	soundEffect('tick');
		
	my $resp = $Self->{'windowGen'}->action();

	if ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'})
	{
		print STDERR "RESP IS $resp\n" if ($Debug);
		FwdSend();
		
	} else {
	
		$Self->{'forwardWindow'}->destroy();
		delete $Self->{'forwardWindow'};
	}
	
	return;
}



# The REAPER is needed to collect dead children, lest they turn to zombies
sub REAPER {
               my $waitedpid = wait;
               # loathe sysV: it makes us not only reinstate
               # the handler, but place it after the wait
	       print STDERR "The REAPER has got you, $waitedpid!" if ($Debug);
               $SIG{CHLD} = \&REAPER;
}


