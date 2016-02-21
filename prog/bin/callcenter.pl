#!/usr/bin/perl



my $License = join( "\n",  
qq|####################  callcenter.pl  #####################|,
qq|####                                                  ####|,
qq|####  Copyright (C) 2002 Pat Deegan, Psychogenic.com  ####|,
qq|####               All rights reserved.               ####|,
qq|####                                                  ####|,
qq|#                                                        #|,
qq|#                 VOCP Call monitoring                   #|,
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
qq|#   at http://www.psychogenic.com and                    #|,
qq|#                                                        #|,
qq|##########################################################|,
);


=head1 NAME

callcenter.pl - Main interface to VOCP GUIs and CID call monitor 

=head1 SYNOPSIS

/path/to/callcenter.pl &

=head1 DESCRIPTION

The VOCP Call Center gives you instant notification of incoming calls,
displaying caller-id information if available.  It also provides easy 
access to the xVOCP and VOCPhax GUIs and to the call log.



=head1 AUTHOR INFORMATION

LICENSE

    VOCP Call Center GUI, part of the VOCP voice messaging system.
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


Address bug reports and comments through the contact info found on 
http://www.VOCPsystem.com or come and see me at http://www.psychogenic.com.


=cut

use FileHandle;
use Data::Dumper;


############## Tk Libs #############
use Tk 8.0;
use Tk::widgets ;
use Tk::Dialog;
use Tk::DialogBox;
use Tk::Image;
use Tk::JPEG;
use Tk::Pixmap;


use VOCP;
use VOCP::Util;
use VOCP::Vars;
use VOCP::Strings;
use VOCP::PipeHandle;
use VOCP::Util::CallMonitor;

use lib '/usr/local/vocp/lib';
use XVOCP;


use strict;

use vars qw {
		$MW
		$Self
		$Vocp
		$TmpDir
		$Debug
		$RefreshAfter
		$RefreshCounter
		$CallMonitor
		%ImageCoords
		$ImageDir
		$XvocpProg 
		$VocphaxProg
		$VocpLocalDir
		$VocpXferProg
		$Lang
		$StartMinimized
	};


$Debug = 0;
$RefreshAfter = 35;
$StartMinimized = 1;
$Lang = 'en'; # future multi-lingual support

$VocpLocalDir = $VOCP::Vars::Defaults{'vocplocaldir'};

$ImageDir = "$VocpLocalDir/images/callcenter";
$XvocpProg = "$VocpLocalDir/bin/xvocp.pl";
$VocphaxProg = "$VocpLocalDir/bin/vocphax.pl";
$VocpXferProg = "$VocpLocalDir/bin/xfer_to_vocp";

{

	my $options = {
		'genconfig'	=> $VOCP::Vars::Defaults{'genconfig'},
		'boxconfig'	=> '',
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1, # no need for logging here...
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck
		
		};
	
	$Self = {};
	
	$Vocp = VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP object");
		
	#We connect to the voicedevice
	$Vocp->connect()
		|| VOCP::Util::error("Unable to Initialize");
	
	
	$TmpDir = $Vocp->{'tempdir'} || $VOCP::Vars::Defaults{'tempdir'} || '/tmp';
	unless (-w  $TmpDir)
	{
		print STDERR "Can't write to $TmpDir\n"
			if ($Debug);
		
		$TmpDir =  (getpwuid($>))[7] ;
		
		unless ( -w $TmpDir)
		{
			print STDERR "Can't write to $TmpDir either - aborting.\n";
			exit (1);
		}
	}
	chdir($TmpDir);
	
	print "\n\n$License\n";
	
	my $cmOpts = {
			'logfile'	=> $Vocp->{'call_logfile'},
			'sleeptime'	=> 1,
		};
	
	$CallMonitor = VOCP::Util::CallMonitor->new($cmOpts);
	
	init();
	
	$CallMonitor->startMonitoring();
	
	$MW->repeat(500, \&UPDATELABEL);
	
	$Self->{'windowGen'} =  XVOCP::WindowGenerator->new(	'parent'	=> $MW,
						);
						
	MainLoop();
	
}


sub UPDATELABEL {

	#print STDERR "In UPDATELABEL\n";
	my $rbits ;
	
	if ($RefreshAfter)
	{
		$RefreshCounter++;
		if ($RefreshCounter > $RefreshAfter)
		{
			$RefreshCounter = 0;
			if ($Self->{'callLabel'})
			{
				$Self->{'callLabel'}->configure(-text => $VOCP::Strings::Strings{$Lang}{'awaitingcall'});
			}
		}
	}
	
	return unless ($CallMonitor->dataWaiting());
	
	$RefreshCounter=0;
	$MW->deiconify();
	$MW->raise();
	
	my ($count, $type, $label, $raw) = $CallMonitor->getData();
	
	return unless ($count && $label);
	
	$label =~ s/(.{20,35})\s/$1\n/g;
	print STDERR "UPDATELBL got $count '$label' ($raw)\n" if ($Debug);
	
	if ($type eq $VOCP::Util::CallMonitor::Message::Type{'INCOMING'})
	{
		if ($Self->{'callLabel'})
		{
			$Self->{'callLabel'}->configure(-text => $label);
			if ($count == 1)
			{
				$MW->configure(-title => 'VOCPCallCenter - 1 call')
			} else {
				$MW->configure(-title => "VOCPCallCenter - $count calls");
			}
		}
	} elsif ($type eq $VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'})
	{
		if ($Self->{'newMsgIndicator'})
		{
			$Self->{'newMsgIndicator'}->configure(-image => $Self->{'newMsgImage'});
		}
		if ($Self->{'callLabel'})
		{
			$Self->{'callLabel'}->configure(-text => $label);
			
		}
	} else {
			print STDERR "Unrecognized type '$type', skipping.\n";
	}
	
	
	
}

sub viewCallLog {

	my $popup = $Self->{'windowGen'}->newWindow(	'type'	=> 'message',
							'name'	=> 'calllog',
							'modal'	=> 1,
							'title'	=> 'VOCP Call Log',
							'parent' => $MW,
							
					);
					
	my $filename = $Vocp->{'call_logfile'} || $VOCP::Vars::Defaults{'calllog'};
	my $callLogFile = FileHandle->new();
	
	unless (-e $filename && $callLogFile->open("<$filename"))
	{
		return VOCP::Util::error("Could not open $filename for read: $!");
	}
	
	my @logLines = $callLogFile->getlines();
	$callLogFile->close();
	
	my @msgList;
	foreach my $line (@logLines)
	{
		my $msg = VOCP::Util::CallMonitor::Message->new($line);
		
		next unless ($msg);
		my $printStr;
		
		my $time = $msg->{'time'} || time();
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
		$year += 1900 if ($year < 1000);
		$mon += 1;
		$mon = "0$mon" if (length($mon) == 1);
		$mday = "0$mday" if (length($mday) == 1);
		$min = "0$min" if (length($min) == 1);
		$hour = "0$hour" if (length($hour) == 1);
		
		
		if ($msg->{'type'} eq $VOCP::Util::CallMonitor::Message::Type{'INCOMING'})
		{
			$printStr = "$year-$mon-$mday $hour:$min";
			if ( ($msg->{'cid'} && $msg->{'cid'} ne 'none') || ($msg->{'cname'} && $msg->{'cname'} ne 'none'))
			{
				
				$printStr .= " $msg->{'cname'} $msg->{'cid'}";
			}
		} elsif ($msg->{'type'} eq $VOCP::Util::CallMonitor::Message::Type{'NEWMESSAGE'})
		{
			$printStr = "Message for " . $msg->{'boxnum'} . ", at $hour:$min on $year-$mon-$mday";
		} else {
			$printStr = 'unknown entry.';
		}
		
		push @msgList, $printStr;
	}
	
	my $listbox = $popup->Scrolled('Listbox',
				 -font 		=> 'fixed -10',
				 -width 	=> 38, 
				 -height 	=> 4, 
				 #-setgrid 	=> 1,
				 -scrollbars 	=> 'oe',
				 -relief 	=> 'flat',
				 %XVOCP::Colors::listbox_attribs)->place( -x =>35, -y => 37);
	
	$listbox->bind('<Double-1>' => \&displayCallLogEntry);
	my $barRelief = 'flat';
	$listbox->Subwidget('xscrollbar')->configure(-relief => $barRelief,-borderwidth =>1, -highlightthickness => 0, 
									%XVOCP::Colors::scrollbar_attribs);
	$listbox->Subwidget('yscrollbar')->configure(-relief => $barRelief, -borderwidth =>1, -highlightthickness => 0, 
									%XVOCP::Colors::scrollbar_attribs);
	$listbox->Subwidget('corner')->configure(-relief => $barRelief, %XVOCP::Colors::labelInv_attribs);			 
	$listbox->delete(0,'end');
	$listbox->insert(0, @msgList);
	$listbox->activate('end');
	$listbox->selectionSet('end');
	$listbox->see('end');
	
	$Self->{'calllogPopup'} = $popup;
	$Self->{'calllogListBox'} = $listbox;
	$popup->update();
	$Self->{'windowGen'}->show('calllog');
	
	delete $Self->{'calllogListBox'};
	delete $Self->{'calllogPopup'};
}


sub displayCallLogEntry {
	
	my $selected = $Self->{'calllogListBox'}->get('active');
	
	my $popup = $Self->{'windowGen'}->newWindow(	'type'	=> 'message',
							'name'	=> 'clogEntry',
							'modal'	=> 0,
							'title'	=> 'Call Log Entry',
							'parent' => $Self->{'calllogPopup'},
							
							
					);
					
	$selected =~ s/(.{20,30}\s)/$1\n/g;
	#$popup->deiconify();
	$popup->Label(-text => $selected,
			%XVOCP::Colors::labelInv_attribs)->place(
						-x => 63,
						-y => 60,
					);
	
	$Self->{'windowGen'}->show('clogEntry');
	
}
	
					

sub startXvocp {
	
	_launchProg($XvocpProg);
	
}



sub startVocphax {

	_launchProg($VocphaxProg);
	
}

sub _launchProg {
	my $prog = shift;
	
	return unless ($prog);
	
	VOCP::Util::error("Can't find program to launch '$prog'")
		unless (-e $prog);
		
	VOCP::Util::error("Program '$prog' not executable")
		unless (-x $prog);
		
	my $childPID = fork();
	if ($childPID)
	{
		# in parent...
		#$SIG{CHLD} = \&REAPER unless ($SIG{CHLD});
		sleep(1);
		return;
	} else {
		
		exec $prog || exit(0);# in case exec somehow fails.
		
	}
	
}
sub startVocp {
	
	# Check the file is present
	unless (-f $VocpXferProg)
	{
		return errorBox($MW, "Cannot find xfer_to_vocp program in $VocpLocalDir");
	}
	
	# Check that it has been setuid by the admin
	unless (-u $VocpXferProg)
	{
		return errorBox($MW, "This function has not been enabled - please contact your VOCP administrator for details");
	}
	
	# Signal vgetty
	my $ret = system($VocpXferProg);
	
	if ($ret)
	{
		return errorBox($MW, "There was problem sending the signal to VOCP ($ret)");
	} else {
		return errorBox($MW, "Pickup signal sent.", "Done");
	}
	
	return;

	
}



sub errorBox {
	my $parentWidget = shift || $MW;
	my $message = shift || 'Unknown error...';
	my $title = shift || "Error";
	
		$Self->{'windowGen'}->errorWindow(
						'modal'	=> 1,
						'title'	=> $title,
						'parent' => $parentWidget,
						'text'	=> $message,
				);
	
	VOCP::Util::log_msg("Error: $message") if ($Debug);
}


sub init {


	%ImageCoords = (
			
			1	=> {
					'x'	=> 63,
					'y'	=> 161,
					'name'	=> 'l_xvocp.jpg',
					'mouseover'	=> 'l_xvocp_over.jpg',
					'method'=> \&startXvocp ,
				},
			2	=> {
					'x'	=> 158,
					'y'	=> 161,
					'name'	=> 'l_calllog.jpg',
					'mouseover'	=> 'l_calllog_over.jpg',
					'method'=> \&viewCallLog,
				},
			3	=> {
					'x'	=> 195,
					'y'	=> 161,
					'name'	=> 'l_vocphax.jpg',
					'mouseover'	=> 'l_vocphax_over.jpg',
					'method'=> \&startVocphax,
				},
			4 	=> {
					'x'	=> 120,
					'y'	=> 161,
					'name'	=> 'l_answer.jpg',
					'mouseover'	=> 'l_answer_over.jpg',
					'method'=> \&startVocp,
				},
			
	);
	$MW = new_mainwindow();
	
	
	
}



sub new_mainwindow {
	my $temp_win = new MainWindow(-title=>'VOCP CallCenter',
					-background => '#09557B',
					-borderwidth => 0,
					-relief => 'flat',
					-height => 313,
					-width => 201);
	
	
	$temp_win->iconname('ccenterico');
	my $xpm = $temp_win->Photo('ccenterico');
	$xpm->read("$VocpLocalDir/images/callcenter/vocplogo.xpm");
	$temp_win->iconimage($xpm);
	
	$temp_win->geometry("313x201");
					
	$temp_win->iconify() if ($StartMinimized);
	#$temp_win->configure( %label_attribs);	
	
	my $bgimage = $temp_win->Photo('bgimage', -file => "$ImageDir/call_center.jpg", -format => 'jpeg');
	my $imglabel = $temp_win->Label(-image => $bgimage, -bg => '#09557B')->place(
						-x => 0,
						-y => 0,
					);
	
	for (my $i = 1; $i <=4; $i++)
	{
		my $imgname = "image0$i";
		VOCP::Util::log_msg("Creating image '$imgname'") if ($Debug > 1);
		
		$Self->{'images'}->{$imgname} = 
					$temp_win->Photo($imgname, -file => "$ImageDir/".$ImageCoords{$i}{'name'}, 
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
			VOCP::Util::log_msg("Creating image '$imgname'") if ($Debug > 1);
		
			$Self->{'images'}->{$imgname} = 
				$temp_win->Photo($imgname, -file => "$ImageDir/".$ImageCoords{$i}{'mouseover'},
							 -format => 'jpeg');
		}
					
		
		
	}
	
	$Self->{'buttons'}->{1}->bind('<Enter>', sub { changeImage(1 , 'on');});	
	$Self->{'buttons'}->{1}->bind('<Leave>', sub { changeImage(1, 'off');});
	
	
	$Self->{'buttons'}->{2}->bind('<Enter>', sub { changeImage(2 , 'on');});	
	$Self->{'buttons'}->{2}->bind('<Leave>', sub { changeImage(2, 'off');});
	
	$Self->{'buttons'}->{3}->bind('<Enter>', sub { changeImage(3 , 'on');});	
	$Self->{'buttons'}->{3}->bind('<Leave>', sub { changeImage(3, 'off');});
	
	$Self->{'buttons'}->{4}->bind('<Enter>', sub { changeImage(4 , 'on');});	
	$Self->{'buttons'}->{4}->bind('<Leave>', sub { changeImage(4, 'off');});
	
	
	
	$Self->{'callLabel'} = $temp_win->Label(-text => $VOCP::Strings::Strings{$Lang}{'awaitingcall'},
							-borderwidth => 0,
							%XVOCP::Colors::labelInv_attribs
							)->place(
							-x => 50,
							-y => 70,
					);
					
	
	
	
	return $temp_win;
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

# The REAPER is needed to collect dead children, lest they turn to zombies
sub REAPER {
               my $waitedpid = wait;
               # loathe sysV: it makes us not only reinstate
               # the handler, but place it after the wait
	       print STDERR "CallCenter REAPER has got you, $waitedpid!" if ($Debug);
               #$SIG{CHLD} = \&REAPER;
}
