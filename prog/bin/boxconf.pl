#!/usr/bin/perl -T -w


=head1 boxconf

A voice/pager/faxondemand/script/command/etc. box configuration GUI, for use with VOCP system.


=head1 SYNOPSIS 

/path/to/boxconf.pl [BOXES.CONFFILE]

BOXES.CONFFILE defaults to /etc/vocp/boxes.conf unless specified.

=head2 DESCRIPTION

This program uses Perl Tk and a number of the VOCP perl modules.  It present a graphical
user interface to aid the VOCP system administrator in creating the required boxes.conf and
boxes.conf.shadow files.  See the doc/boxconf.txt and doc/box-config-file.txt HOWTOs for
details.

=head2 AUTHOR

    boxconf.pl, part of the VOCP voice messaging system
    Copyright (C) 2002 Patrick Deegan, Psychogenic.com
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


my $License = join( "\n",  
qq|####################### boxconf.pl #######################|,
qq|####                                                  ####|,
qq|####  Copyright (C) 2002 Pat Deegan, Psychogenic.com  ####|,
qq|####               All rights reserved.               ####|,
qq|####                                                  ####|,
qq|#                                                        #|,
qq|#             VOCP Box Configuration Admin               #|,
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

use Tk 8.0;
use Tk::widgets ;
use Tk::NoteBook;
use Tk::Dialog;
use Tk::DialogBox;
use Tk::NoteBook;
use Tk::LabEntry;
use Tk::Optionmenu;
use Data::Dumper;

use VOCP;
use VOCP::Box;
use VOCP::Vars;
use VOCP::Strings;


use lib '/usr/local/vocp/lib';
#use lib '../lib';
use XVOCP;

use strict;


use vars qw {
	$Debug
	$Version
	%Strings
	$DefaultLang
	$SupportedLangs
	$BoxConfigFile
	$GenConfigFile
	$Lang
	$MW
	$BoxList
	$NewBut
	$EditBut
	$DelBut
	$CmdBoxList
	$FaxBoxList
	$Vocp
	@VocpBoxes
	@FaxBoxes
	@CommandBoxes
	$EditWindow
	@SystemUsers
	$NewBoxWindow
	$CommandWindow
	$CommandWinList
	$SelectedCommandBox
	$ChangesMade
	%FillVars
	$VocpLocalDir
	$Self
	
	};

$Debug = 0; #Set > 0 for more verbose logging, >1 for very verbose

$BoxConfigFile = shift @ARGV || $VOCP::Vars::DefaultConfigFiles{'boxconfig'};
$GenConfigFile = $VOCP::Vars::DefaultConfigFiles{'genconfig'};
$Version = '1.0';

$VocpLocalDir = $VOCP::Vars::Defaults{'vocplocaldir'} || '/usr/local/vocp';

%Strings = (

		'en' => {
				'aboutblurb'	=> "About boxconf\n\nX interface to VOCP box configuration\n\n"
							."(C) 2002 Pat Deegan (www.psychogenic.com)\n\nwww.VOCPsystem.com",
				'versionblurb'	=> "VOCP boxconf version $Version",
		},
	
			
		'fr'	=> {	
				'aboutblurb'	=> "A propos de boxconf\n\nInterface graphique a la configuration de boite VOCP\n\n"
							."(C) 2002 Pat Deegan (www.psychogenic.com)\n\nwww.VOCPsystem.com",
				'versionblurb'	=> "boxconf\n\nVersion $Version. Aout. 2002",
		},
	);


# Language related vars
$DefaultLang = 'en';
$SupportedLangs =  'en|fr';

$ChangesMade = 0;
# Taint check stuff
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
$ENV{'BASH_ENV'}="/etc/bashrc";
if ($ENV{'HOME'} =~ m|^(.*)$|)
{
	# Cheap taint checking
	$ENV{'HOME'} = $1;
	# As we don't actually use the $HOME, it /shouldn't/ matter
	# if we set it to some bogus know to be safe value
	# but since it's used by X display forwarding we need to leave
	# it unmodified.
	
}


# Get, validate and untaint current language
$Lang = shift @ARGV || $DefaultLang;
die "Unsupported language '$Lang'" unless ($Lang =~ m|^($SupportedLangs)$|);
$Lang = $1; 


print "\n\n$License\n";



############ UI attributes (colors etc.) ################
my %DefUIAttrib = (
		'background'	=> '#00566F',
		'foreground'	=> '#d4c77c',
		'activebackground'	=> '#0A6179',
		'relief'	=> 'groove',
		'highlbackground'	=> '#055A74',
		);
		
my %Button_colors = (
		'-activebackground' => $XVOCP::Colors::DefUIAttrib{'activebackground'},
     		'-activeforeground' => $XVOCP::Colors::DefUIAttrib{'foreground'},
     		'-background' => $XVOCP::Colors::DefUIAttrib{'background'},
     		'-foreground' => $XVOCP::Colors::DefUIAttrib{'foreground'},
		);
	
my %Option_attribs = (
		'-activebackground' => $XVOCP::Colors::DefUIAttrib{'activebackground'},
     		'-activeforeground' => $XVOCP::Colors::DefUIAttrib{'foreground'},
     		'-background' => $XVOCP::Colors::DefUIAttrib{'background'},
     		'-foreground' => $XVOCP::Colors::DefUIAttrib{'foreground'},
		);
	
my %Listbox_attribs = (
		-background => '#ccccdd',
		-foreground => $XVOCP::Colors::DefUIAttrib{'highlbackground'},
		-selectbackground => $XVOCP::Colors::DefUIAttrib{'activebackground'},
		-selectforeground => $XVOCP::Colors::DefUIAttrib{'foreground'},
	);
	
my %Label_attribs = (
			-background => $XVOCP::Colors::DefUIAttrib{'background'},
			-foreground => $XVOCP::Colors::DefUIAttrib{'foreground'},
	);
my %Frame_attribs = (
			-background => $XVOCP::Colors::DefUIAttrib{'background'},
			-relief => $XVOCP::Colors::DefUIAttrib{'relief'},
	);
my %Labentry_attribs = ( 
			-labelBackground => $XVOCP::Colors::DefUIAttrib{'background'},
			-labelForeground => $XVOCP::Colors::DefUIAttrib{'foreground'},
			%Listbox_attribs
	);
	
my %MenuButton_colors = (
			'-activebackground' => $XVOCP::Colors::DefUIAttrib{'activebackground'},
	 		'-activeforeground' => $XVOCP::Colors::DefUIAttrib{'foreground'},
	 		'-background' => $XVOCP::Colors::DefUIAttrib{'background'},
	 		'-foreground' => $XVOCP::Colors::DefUIAttrib{'foreground'},
		);



my %Scrollbar_attribs = (
		'-highlightbackground' => $XVOCP::Colors::DefUIAttrib{'highlbackground'},
		'-highlightcolor'	=> '#EEEEFF',
		'-activebackground' => $XVOCP::Colors::DefUIAttrib{'activebackground'},
     		'-background' => $XVOCP::Colors::DefUIAttrib{'background'},
		'-troughcolor'	=> '#002439',
     	);

# main 
{

	my $options = {
		'genconfig'	=> $GenConfigFile,
		'boxconfig'	=> $BoxConfigFile,
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1,
		};
		
	$Vocp = VOCP->new($options)
		|| VOCP::error("Unable to create new VOCP instance.");
	
	$MW = MainWindow->new(-title=>'VOCP boxconf', -background => $XVOCP::Colors::DefUIAttrib{'background'});
	
	$Self = {};
	bless $Self;
	
	$Self->{'windowGen'} =  XVOCP::WindowGenerator->new(	'parent'	=> $MW,
						);
	
	my @users;
	$users[0] = 'none';
	while (my $name  = getpwent())
	{
		push @users, $name;
	}
	
	@SystemUsers = (sort @users);
	
	
	
	init();
	MainLoop();


	exit(0);
}


sub showHelp {

	$Self->{'windowGen'}->helpWindow(
							'modal'	=> 0,
							'title'	=> "Help",
							'file' =>"$VocpLocalDir/doc/boxconf.txt",
							'forceuntaint'	=> 1,
							
					);

	return;
}
#-------------------------------------------------------------
#  Creates and returns the menubar widget.
#  Called from init at startup
#------------------------------------------------------------
sub build_menubar {

	
	my $menubar = $MW->Menu(-type => 'menubar', %MenuButton_colors);
	$MW->configure(-menu=>$menubar);

	## file menu
	my $file=$menubar->cascade(-label =>"~$VOCP::Strings::Strings{$Lang}{'file'}", -tearoff =>0, %MenuButton_colors);
	$file->command(-label => $VOCP::Strings::Strings{$Lang}{'save'}, -command => \&save, %MenuButton_colors);
	$file->command(-label => $VOCP::Strings::Strings{$Lang}{'quit'}, -command => \&Exit, %MenuButton_colors);
	
	my $edit = $menubar->cascade(-label =>"~$VOCP::Strings::Strings{$Lang}{'edit'}", -tearoff =>0, %MenuButton_colors);
	$edit->command(-label => $VOCP::Strings::Strings{$Lang}{'newbox'}, -command => \&newBoxSelect, %MenuButton_colors);
	$edit->command(-label => $VOCP::Strings::Strings{$Lang}{'editbox'}, -command => \&editBox, %MenuButton_colors);
	$edit->command(-label => $VOCP::Strings::Strings{$Lang}{'delbox'}, -command => \&delBox, %MenuButton_colors);
	$edit->command(-label => $VOCP::Strings::Strings{$Lang}{'delallboxes'}, -command => \&delAllBoxes, %MenuButton_colors);

	## help menu
	my $help=$menubar->cascade(-label =>"~$VOCP::Strings::Strings{$Lang}{'help'}", -tearoff =>0, %MenuButton_colors);
	$help->command(-label => $VOCP::Strings::Strings{$Lang}{'help'}, 
			-command => \&showHelp, %MenuButton_colors);
	$help->command(-label => $VOCP::Strings::Strings{$Lang}{'version'}, %MenuButton_colors);
	#$help->separator;
	$help->command(-label => $VOCP::Strings::Strings{$Lang}{'about'}, %MenuButton_colors);

	## help menu dialogs
	my $vers = $MW->Dialog(-title => $VOCP::Strings::Strings{$Lang}{'versiontitle'},
	                       -text  => $Strings{$Lang}{'versionblurb'},
	                       -buttons  => ['OK'],
	                       -bitmap => 'info');
	
	
	$vers->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -highlightbackground => '#000000');
	
	$vers->Subwidget('B_OK')->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, 
								-activeforeground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -activebackground => $XVOCP::Colors::DefUIAttrib{'activebackground'});
	
	my $about = $MW->Dialog(-title =>$VOCP::Strings::Strings{$Lang}{'abouttitle'} ,
				-text  => $Strings{$Lang}{'aboutblurb'},
				-buttons  => ['OK']);
	$about->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -highlightbackground => '#000000');
	
	$about->Subwidget('B_OK')->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, 
								-activeforeground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -activebackground => $XVOCP::Colors::DefUIAttrib{'activebackground'});
	
	## bind dialogs to help menu entries
	my $menu = $help->cget('-menu');
	$menu->entryconfigure($VOCP::Strings::Strings{$Lang}{'version'}, -command => [$vers => 'Show']);
	$menu->entryconfigure($VOCP::Strings::Strings{$Lang}{'about'}, -command => [$about => 'Show']);


	return $menubar     # return just built menubar

} # end build_menubar




#-------------------------------------------------------------
#  Creates most application widgets 
#  Called from main at startup
#------------------------------------------------------------
sub init {
	
	$MW->title("VOCP boxconf $Version");
	
	# set icon when minimized
	$MW->iconname('boxconf');
	my $xpm = $MW->Photo('boxconf');
	$xpm->read("$VocpLocalDir/images/vocpicon.xpm");
	$MW->iconimage($xpm);
	
	# menu
	my $mb = build_menubar;
	
	############################################
	###	LOGO		MESSAGE		####
	###	BOXLABEL	MSGLABEL 	####
	###	BOXLIST		MSGLIST		####
	###	 --	
	# labels
	my $logo = $MW->Pixmap('vocplogo', -file => $VOCP::Vars::Defaults{'vocplocaldir'} . '/images/vocplogo.xpm');
	
	my $Instructions = $MW->Label(-text => $VOCP::Strings::Strings{$Lang}{'boxconfinfo'}, %Label_attribs 
				)->grid(qw/-row 0 -column 0 -columnspan 2/);
	
	
	# my $boxlabel = $MW->Label(-text => $VOCP::Strings::Strings{$Lang}{'boxlabel'})->grid(qw/-row 1 -column 0/);
	my $boxlabel = $MW->Label(-text => $VOCP::Strings::Strings{$Lang}{'boxlabel'}, %Label_attribs)->grid(qw/-row 1 -column 0 -columnspan 2/);
	
	
	$BoxList = $MW->Scrolled('Listbox',
	  	-font => 'fixed',
		-width => 52,
		-height => 15, 
		-setgrid => 1, 
		-scrollbars => 'ose',
		%Listbox_attribs
		);
	$BoxList->Subwidget('xscrollbar')->configure(%Scrollbar_attribs);
	$BoxList->Subwidget('yscrollbar')->configure(%Scrollbar_attribs);
	$BoxList->Subwidget('corner')->configure(%Label_attribs);
	
	
	$BoxList->grid(qw/-row 2 -columnspan 2 -sticky nsew/);
	#$BoxList->grid(qw/-row 2 -column 0/);
	$BoxList->bind('<Double-1>' => \&editBox);
	
	my $bts = $MW->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'},
		-relief => $XVOCP::Colors::DefUIAttrib{'relief'})->grid(qw/-row 3 -columnspan 2/);
	$NewBut = $bts->Button(-text => $VOCP::Strings::Strings{$Lang}{'newbox'}, -command => \&newBoxSelect,
					%Button_colors)->pack(qw/-side left -expand 1 -fill x/);
	$EditBut = $bts->Button(-text => $VOCP::Strings::Strings{$Lang}{'editbox'}, -command => \&editBox,
					%Button_colors)->pack(qw/-side left -expand 1 -fill x/);
	$DelBut = $bts->Button(-text => $VOCP::Strings::Strings{$Lang}{'delbox'}, -command => \&delBox,
					%Button_colors)->pack(qw/-side left -expand 1 -fill x/);
	
	
	
	my $frame2 = $MW->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'},
		-relief => $XVOCP::Colors::DefUIAttrib{'relief'})->grid(
		-row => 4, 
		-columnspan => 2);
	my $cmdboxlabel = $frame2->Label(-text => $VOCP::Strings::Strings{$Lang}{'cmdboxlabel'}, %Label_attribs)->pack(qw/-side left -expand 0 /);
	
	
	my $frame3 = $MW->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'},
		-relief => $XVOCP::Colors::DefUIAttrib{'relief'})->grid(qw/-row 5 -columnspan 2/);
	$CmdBoxList = $frame3->Scrolled('Listbox', -font	=> 'fixed',
					 -width		=> 6, 
					 -height 	=> 4,
					 -setgrid 	=> 1, 
					 -scrollbars 	=> 'oe',
					 %Listbox_attribs);
					 
	#$CmdBoxList->grid(qw/-row 5 -column 0/);
	$CmdBoxList->pack(qw/-side left -expand 0 /);
	$CmdBoxList->bind('<Double-1>' => \&editCommands);
	
	
	
	my $botbts = $MW->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'},
		-relief => $XVOCP::Colors::DefUIAttrib{'relief'})->grid(qw/-row 6 -columnspan 2/);
	my $savebut = $botbts->Button(-text => $VOCP::Strings::Strings{$Lang}{'save'}, 
					-command => \&save, %Button_colors)->pack(qw/-side left -expand 1 -fill x/);
	my $quitbut = $botbts->Button(-text => $VOCP::Strings::Strings{$Lang}{'quit'}, -command => \&Exit,
					%Button_colors)->pack(qw/-side right -expand 1 -fill x/);
	
	my $LogoImage = $MW->Label(-image => $logo, %Label_attribs )->grid(qw/-row 7 -column 0/);
	my $botlabel = $MW->Label(-text => $VOCP::Strings::Strings{$Lang}{'bottomlabel'}, -font => 'fixed', %Label_attribs )->grid(qw/-row 7 -column 1 /);
	
	
	refreshBoxLists();
	
} # end init


sub refreshBoxLists {


	if (scalar @VocpBoxes)
	{
		$BoxList->delete(0, $#VocpBoxes);
		$CmdBoxList->delete(0, $#VocpBoxes);
		#$FaxBoxList->delete(0, $#VocpBoxes);
	}
	
	my $boxes = $Vocp->get_box_list('UNTAINT');
	
	my @displayBoxes;
	@VocpBoxes = ();
	@CommandBoxes = ();
	#@FaxBoxes = ();
	
	$displayBoxes[0] = $VOCP::Strings::Strings{$Lang}{'boxlisttitle'};
	foreach my $box (@{$boxes})
	{
		my $boxnum = $box->{'number'};
		my $type = $box->{'type'};
		
		if ($type eq 'command')
		{
			$CommandBoxes[scalar @CommandBoxes] = $boxnum;
		} 
		
		$type =~ s/^(.{8}).+/$1/;
		
		my $message = $box->{'message'};
		
		$message =~ s|$Vocp->{'messagedir'}/||g;
		#$message =~ s|\.rmd$||;
		
		my $boxname = $box->{'name'} || '';
		$boxname =~ s/^(.{10}).+$/$1/;
		my $owner = $box->{'owner'};
		
		
		my $string = $boxnum . ' ' x (5 - length($boxnum)) . $type 
				. ' ' x (9 - length($type)) . $boxname
				. ' ' x (12 - length($boxname)) . $owner 
				. ' ' x (10 - length($owner)) . $message 
				. ' ' x (20 - length($message)) . $box->{'branch'} . ' ';
		
		my $idx = scalar @displayBoxes;
		$displayBoxes[$idx]  = $string;
		
		$VocpBoxes[$idx] = $boxnum;
	}
	
	$BoxList->insert(0, @displayBoxes);
	
	if (scalar @CommandBoxes) {
		$CmdBoxList->insert(0, @CommandBoxes);
	}
	
	#if (scalar @FaxBoxes) {
	#	$FaxBoxList->insert(0, @FaxBoxes);
	#}
		
}


sub newBoxSelect {
	my $temp_win = $MW->DialogBox(-title=>'Select a box type', -background => $XVOCP::Colors::DefUIAttrib{'background'},
					-buttons => ['OK', 'Cancel']);

	#$temp_win->withdraw();

	my $newBoxSelect = $temp_win;
	$newBoxSelect->Subwidget('B_OK')->configure(%Button_colors);     
	$newBoxSelect->Subwidget('B_Cancel')->configure(%Button_colors); 
	
	my $frame = $newBoxSelect->add('Frame',
		-borderwidth => '3',
		-background => $XVOCP::Colors::DefUIAttrib{'background'},
		-relief => $XVOCP::Colors::DefUIAttrib{'relief'})->pack(
						-side => 'top', -expand => 1);
		
	$frame->Label(-text => ' ', %Label_attribs
	)->pack(-side => "top", -expand => 1);
	$frame->Label(-text => 'Please select a box type', %Label_attribs
	)->pack(-side => "top", -expand => 1);

	
	my @options = sort @VOCP::Vars::Valid_box_types;
	$FillVars{'newBoxType'} = '';
	my $opmen = getOptionMenu($frame, \@options, \$FillVars{'newBoxType'} ,%Option_attribs);
	$opmen->configure(%Button_colors);
	
	$FillVars{'newBoxType'} = 'none';
	
	$opmen->pack(-side => "bottom", -expand => 0);
	$frame->Label(-text => '  ', %Label_attribs
	)->pack(-side => "bottom", -expand => 1);
	
	my $result = $newBoxSelect->Show();
	
	
	return unless ($result eq 'OK');
	
	my $selected = $FillVars{'newBoxType'};
	my $subEnd;
	if ( $selected eq 'none' || (! $selected))
	{
		$subEnd = 'none';
	} else {
		$subEnd = $selected;
	}
	
	my $subName = "create_new_$subEnd";
	die "Unsupported box type '$selected'" unless $Self->can($subName);
	
	$Self->$subName();
	
	

}


sub create_new_none {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'none';
	
	my $boxDetails = genericNewBoxWindow($defaults);
	addFlowInfo($boxDetails, $defaults);
	addCNDRestrictions($boxDetails, $defaults);
	my $result = $boxDetails->Show();

	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
	
}


sub create_new_mail {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'mail';

	my $boxDetails = genericNewBoxWindow($defaults);
	addOwnerInfo($boxDetails, $defaults);
	addCNDRestrictions($boxDetails, $defaults);

	my $result = $boxDetails->Show();

	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
		
	
}



sub create_new_command {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'command';
	
	my $boxDetails = genericNewBoxWindow($defaults);
	addOwnerInfo($boxDetails, $defaults);
	addCNDRestrictions($boxDetails, $defaults);
	
	my $result = $boxDetails->Show();
	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
		
	
}


sub create_new_group {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'group';
	
	my $boxDetails = genericNewBoxWindow($defaults);
	
	my $memberFrame = $boxDetails->add('Frame', %Frame_attribs)->grid(qw/-row 3 /);
	
	$memberFrame->Label(-text => "\nMembers", %Label_attribs)->pack(qw/-side top -expand 0 /);

	$memberFrame->LabEntry(-label => "",
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 30,
	     -textvariable => \$FillVars{'members'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 
  
	$FillVars{'members'} = $defaults->{'members'} || '';
	addCNDRestrictions($boxDetails, $defaults);
	my $result = $boxDetails->Show();
	
	$FillVars{'members'} =~ s/\s+//g;
	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
		
	
	
}


sub create_new_script {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'script';

	my $boxDetails = genericNewBoxWindow($defaults);
	addOwnerInfo($boxDetails, $defaults);
	
	addFlowInfo($boxDetails, $defaults);
	
	my $scriptFrame = $boxDetails->add('Frame', %Frame_attribs)->grid(qw/-row 6 /);
	
	$scriptFrame->Label(-text => "\nProgram", %Label_attribs)->pack(qw/-side top -expand 0 /);

	$scriptFrame->LabEntry(-label => "Path: ",
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 40,
	     -textvariable => \$FillVars{'script'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 
  
	my $scriptFrame2 = $boxDetails->add('Frame', %Frame_attribs)->grid(qw/-row 7 /);
	$scriptFrame2->Label(-text => "  " . $VOCP::Strings::Strings{$Lang}{'cmdinput'},
				%Label_attribs)->pack(qw/-side left -expand 0 /);

	my @inputOptions = split('\|', $VOCP::Box::Script::ValidInput);
	my $inOptMenu = getOptionMenu($scriptFrame2, \@inputOptions, \$FillVars{'input'},%Option_attribs);
	$inOptMenu->configure(%Button_colors);
	$inOptMenu->pack(-side => "left", -expand => 0);
	
	#my $scriptFrame3 =  $boxDetails->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'})->grid(qw/-row 5 /);
	
	$scriptFrame2->Label(-text => $VOCP::Strings::Strings{$Lang}{'cmdreturn'},%Label_attribs)->pack(qw/-side left -expand 0 /);

	my @outputOptions = sort @VOCP::Vars::Valid_cmd_return_types;
	my $retOptMenu = getOptionMenu($scriptFrame2, \@outputOptions, \$FillVars{'return'},%Option_attribs);
	$retOptMenu->configure(%Button_colors);
	$retOptMenu->pack(-side => "left", -expand => 0);
	
	
	$FillVars{'script'} = $defaults->{'script'};
	$FillVars{'input'} = $defaults->{'input'};
	$FillVars{'return'} = $defaults->{'return'};
	
	
	addCNDRestrictions($boxDetails, $defaults);
	my $result = $boxDetails->Show();
	
	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
	
}


sub create_new_faxondemand {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'faxondemand';

	my $boxDetails = genericNewBoxWindow($defaults);
	
	
	my $faxFrame = $boxDetails->add('Frame', %Frame_attribs)->grid(qw/-row 3 /);
	
	$faxFrame->Label(-text => "\nFax To Send", %Label_attribs)->pack(qw/-side top -expand 0 /);

	$faxFrame->LabEntry(-label => "Path:",
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 40,
	     -textvariable => \$FillVars{'file2fax'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 
  
	$FillVars{'file2fax'} = $defaults->{'file2fax'};
	
	
	addCNDRestrictions($boxDetails, $defaults);
	my $result = $boxDetails->Show();
	
	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
		
}


sub create_new_exit {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'exit';
	
	my $boxDetails = genericNewBoxWindow($defaults);
	addCNDRestrictions($boxDetails, $defaults);
	my $result = $boxDetails->Show();
	
	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
	
}

sub create_new_receivefax {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'receivefax';
	
	my $boxDetails = genericNewBoxWindow($defaults);
	addCNDRestrictions($boxDetails, $defaults);
	my $result = $boxDetails->Show();
	
	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
		

	
}

sub create_new_pager {
	my $self = shift;
	my $defaults = shift || {};
	
	clearNewBoxFillVars(\%FillVars);
	
	$defaults->{'type'} = 'pager';
		
	my $boxDetails = genericNewBoxWindow($defaults);
	addOwnerInfo($boxDetails, $defaults);
	
	addCNDRestrictions($boxDetails, $defaults);
	my $result = $boxDetails->Show();
	
	if ($result eq 'Ok')
	{
		$self->_createBox($defaults);
	}
		

	
}

sub _createBox {
	my $self = shift;
	my $defaults = shift;
	
	my $boxFactory = $Vocp->{'boxFactory'};
	
	
	
	my %params;
	$params{'type'} = $FillVars{'type'}; # ensure we have type set
	while (my ($key, $val) = each %FillVars)
	{
		$val ||= '';
		next if ($val eq '' || $val eq 'none');
		$params{$key} = $val;
	}
	my $newBox;
	
	my $olddie = $VOCP::Util::Die_on_error;
	$VOCP::Util::Die_on_error = 1;
		
	eval {
		$newBox = $boxFactory->newBox(%params);
	};
	
	if ($@)
	{
		my $errStr = $@;
		$errStr =~ s|at /\S+Util.pm line .*$||;
		errorBox($MW, "Error: $errStr");
		return undef;
	}
	
	my $oldBoxCmndSelections; 
	if ($defaults->{'number'})
	{
		# This is an edit
		my $oldBox = $Vocp->get_box_object($defaults->{'number'});
		
		if ($oldBox)
		{
			my $btype = $oldBox->type();
			
			$oldBoxCmndSelections = $oldBox->getAllSelections() if ($btype && $btype eq 'command');
		}
		if ($defaults->{'number'} ne $FillVars{'number'})
		{
			# We've changed the box number
			# Check if we're overwritting...
			my $overWrite = $Vocp->get_box_object($FillVars{'number'});
			
			if ($overWrite)
			{
				my $conf = confirmBox($MW, $VOCP::Strings::Strings{$Lang}{'overwrite?'} . $FillVars{'number'} . "?");
				return undef unless ($conf eq 'Ok');
			}
			
			if ($oldBox)
			{
				# We need to delete the old box.
				$Vocp->delete_box($defaults->{'number'});
			}
		} else {
		
			
			# No change to box number - simple edit.
			# destroy the original version of the box
			$Vocp->delete_box($defaults->{'number'});
		}
		
	} else {
		my $overWrite = $Vocp->get_box_object($FillVars{'number'});
				
		if ($overWrite)
		{
			my $conf = confirmBox($MW, $VOCP::Strings::Strings{$Lang}{'overwrite?'} . $FillVars{'number'} . "?");
			return undef unless ($conf eq 'Ok');
		}
		$Vocp->delete_box($FillVars{'number'});
		
		
	} # end if this is an edit	
	
	
	
	if ($oldBoxCmndSelections && $newBox->type eq 'command')
	{
		# if it WAS and still IS a command box, reset all the command selections
		foreach my $selection (@{$oldBoxCmndSelections})
		{
			next unless ($selection->{'run'});
			
			$newBox->selection($selection->{'selection'}, 
						$selection->{'input'}, 
						$selection->{'return'} || 'exit', 
						$selection->{'run'});
						
		}
	}
	
	$Vocp->{'boxes'}->{$FillVars{'number'}} = $newBox;
	
	$ChangesMade++;
	
	refreshBoxLists();
	
}

sub clearNewBoxFillVars {
	my $var = shift;
	
	$var->{'number'} = '';
	$var->{'owner'} = '';
	$var->{'autojump'} = '';
	$var->{'branch'} = '';
	$var->{'password'} = '';
	$var->{'type'} = '';
	$var->{'message'} = '';
	$var->{'email'} = '';
	$var->{'restricted'} = '';
	$var->{'script'} = '';
	$var->{'file2fax'} = '';
	$var->{'members'} = '';
	$var->{'input'} = '';
	$var->{'return'} = '';
	$var->{'name'} = '';
	$var->{'restrictFrom'} = '';
	$var->{'restrictLoginFrom'} = '';
	$var->{'numDigits'} = '';

	
}
	

# Grid rows 3,6 and 7 are unoccupied.
# grid rows 0-2

sub genericNewBoxWindow {
	my $defaults = shift || {};
		
	$FillVars{'type'} = $defaults->{'type'};
	
	my $boxWindow = $MW->DialogBox(-title => $VOCP::Strings::Strings{$Lang}{'addbox'}, -background => $XVOCP::Colors::DefUIAttrib{'background'},
			     -buttons => ["Ok", "Cancel"]);
	$boxWindow->Subwidget('B_Ok')->configure(%Button_colors);     
	$boxWindow->Subwidget('B_Cancel')->configure(%Button_colors); 
	my $labelfrm = $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 0 /);
	my $label = $labelfrm->Label(-text => $VOCP::Strings::Strings{$Lang}{'entervals'}, %Label_attribs)->pack(qw/-side left -expand 0 /);


	my $nameFrame = $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 1 /);
	
	
	$nameFrame->Label(-text => "$defaults->{'type'} " 
					. $VOCP::Strings::Strings{$Lang}{'box'},%Label_attribs)->pack(qw/-side top -expand 0 /);

	
	$nameFrame->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'name'},
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 20,
	     -textvariable => \$FillVars{'name'},
	     %Labentry_attribs )->pack(-side => "left", -expand => 0);

	
	my $stufffrm =  $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 2 /);

	$stufffrm->Label(-text => " ",%Label_attribs)->pack(qw/-side top -expand 0 /);

	$stufffrm->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'num'},
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 5,
	     -textvariable => \$FillVars{'number'},
	     %Labentry_attribs )->pack(-side => "left", -expand => 0);

	#my @options = sort @VOCP::Vars::Valid_box_types;
	#my $opmen = getOptionMenu($stufffrm, \@options, \$addType,%Option_attribs);
	#$opmen->configure(%Button_colors);
	#$opmen->pack(-side => "left", -expand => 0);
	
	
	
	$stufffrm->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'message'},
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 20,
	     -textvariable => \$FillVars{'message'},
	     %Labentry_attribs )->pack(-side => "left", -expand => 0); 

	$FillVars{'name'} = $defaults->{'name'};
	$FillVars{'number'} = $defaults->{'number'};
	$FillVars{'type'} = $defaults->{'type'};
	$FillVars{'message'} = $defaults->{'message'};
	
	return $boxWindow;
}
	

# grid 3 avail
# grid row 4-5

sub addOwnerInfo {
	my $boxWindow = shift;
	my $defaults = shift;


	##### 2nd row ####
	my $ownerframe =  $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 4 /);

	$ownerframe->Label(-text => "\n".$VOCP::Strings::Strings{$Lang}{'owner'} . ' ', %Label_attribs)->pack(qw/-side top -expand 0 /);

	my $opmen2 = getOptionMenu($ownerframe, \@SystemUsers,\$FillVars{'owner'}, %Option_attribs);
	$opmen2->configure(%Button_colors);
	$opmen2->pack(-side => "left", -expand => 0);
	
	$ownerframe->LabEntry(-label => ' ' . $VOCP::Strings::Strings{$Lang}{'passwd'} . ' ',
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 12,
	     -textvariable => \$FillVars{'password'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 

	my $ownerFrame2 = $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 5 /);
	
	$ownerFrame2->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'email'} . ' ',
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 25,
	     -textvariable => \$FillVars{'email'},
	     %Labentry_attribs)->pack(-side => "bottom", -expand => 0); 
   

	
	$FillVars{'owner'} = $defaults->{'owner'};
	$FillVars{'password'} = $defaults->{'password'};
	$FillVars{'email'} = $defaults->{'email'};
	
	return $boxWindow;
}

# grid row 6-7 avail
# grid row 8
sub addFlowInfo {
	my $boxWindow = shift;
	my $defaults = shift;
	
	
	my $frame1 =  $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 8/);
	
	$frame1->Label(-text => "\n".$VOCP::Strings::Strings{$Lang}{'callflow'}, %Label_attribs)->pack(qw/-side top -expand 0 /);


	$frame1->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'branch'},
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 25,
	     -textvariable => \$FillVars{'branch'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 
  

	$frame1->LabEntry(-label => ' ' . $VOCP::Strings::Strings{$Lang}{'restricted'},
		-labelPack => [-side => "left", -expand => 0],
		-width => 12,
		-textvariable => \$FillVars{'restricted'},
		%Labentry_attribs)->pack(-side => "left", -expand => 0);
 
 
 	my $frame2 =  $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 9/);
	$frame2->Label(-text => " ", %Label_attribs)->pack(qw/-side top -expand 0 /);

	 
	
	$frame2->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'autojump'},
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 6,
	     -textvariable => \$FillVars{'autojump'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 

	$frame2->LabEntry(-label => ' ' . $VOCP::Strings::Strings{$Lang}{'numDigits'},
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 3,
	     -textvariable => \$FillVars{'numDigits'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0);
	
	
 	$FillVars{'numDigits'} =  $defaults->{'numDigits'};
	$FillVars{'autojump'} = $defaults->{'autojump'};
	$FillVars{'branch'} = $defaults->{'branch'};
	$FillVars{'restricted'} = $defaults->{'restricted'};
	
	
	
	return $boxWindow;
}
 
# grid row 10
sub addCNDRestrictions {
	my $boxWindow = shift;
	my $defaults = shift;


	my $cndframe =  $boxWindow->add('Frame', %Frame_attribs)->grid(qw/-row 10 /);

	$cndframe->Label(-text => "\n".$VOCP::Strings::Strings{$Lang}{'cndrestrict'}, %Label_attribs)->pack(qw/-side top -expand 0 /);

	
	$cndframe->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'restrictLoginFrom'} . ' ',
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 16,
	     -textvariable => \$FillVars{'restrictLoginFrom'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 

	$cndframe->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'restrictFrom'} . ' ',
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 16,
	     -textvariable => \$FillVars{'restrictFrom'},
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 

	$FillVars{'restrictLoginFrom'} = $defaults->{'restrictLoginFrom'};
	$FillVars{'restrictFrom'} = $defaults->{'restrictFrom'};
	
	
	return $boxWindow;
}


sub editBox {
	my $tkstuff = shift;
	
	my $selected= $BoxList->index('active');
    
   	return undef unless ($selected);
	
	my $boxnum = $VocpBoxes[$selected] || die "Selected invalid value!? '$selected'";
	
	my $boxObject = $Vocp->get_box_object($boxnum);
	
	my $details = $boxObject->getDetails($boxnum);
	
	my $type = $details->{'type'} || 'none';
	
	my $subEnd;
	if ( $type eq 'none' || (! $type))
	{
		$subEnd = 'none';
	} else {
		$subEnd = $type;
	}
	
	my $subName = "create_new_$subEnd";
	
	die "Unsupported box type '$type'" unless $Self->can($subName);
	
	$Self->$subName($details);
}


	
	
sub delBox {
	my $selected= $BoxList->index('active');
    
   	return undef unless ($selected);
	
	my $boxnum = $VocpBoxes[$selected] || die "Selected invalid value!? '$selected'";
	
	return undef if ($boxnum eq $VOCP::Default_box);
	
	my $resp = confirmBox($MW, $VOCP::Strings::Strings{$Lang}{'reallydelete'} . $boxnum . '?',$VOCP::Strings::Strings{$Lang}{'reallydeletetitle'});
	
	return undef unless ($resp eq 'Ok');
	
	$Vocp->delete_box($boxnum);
	$ChangesMade++;
	refreshBoxLists();
	
	print STDERR "DELETE: $boxnum\n" if ($Debug);
}

sub delAllBoxes {
	
	my $resp = confirmBox($MW, $VOCP::Strings::Strings{$Lang}{'reallydelete'} . $VOCP::Strings::Strings{$Lang}{'allboxes'} . '?',
				$VOCP::Strings::Strings{$Lang}{'reallydeletetitle'});
	
	return undef unless ($resp eq 'Ok');
	
	
	foreach my $boxnum (keys %{$Vocp->{'boxes'}})
	{
		next if ($boxnum eq $VOCP::Vars::Defaults{'rootboxnum'});
		
		delete $Vocp->{'boxes'}->{$boxnum};
	}
	
	$ChangesMade++;
	refreshBoxLists();
	
	print STDERR "DELETE: All boxes.\n" if ($Debug);
}


sub editCommands {
	my $selected= $CmdBoxList->index('active');
    
   	return undef unless (defined $selected);
	
	my $boxnum = $CommandBoxes[$selected] || die "Selected invalid value!? '$selected'";
	
	my $details = $Vocp->get_box_details($boxnum);
	
	die "What?? Box $boxnum is not a command box." 
		if ($details->{'type'} ne 'command');
	
	$SelectedCommandBox = $boxnum;
	
	
	$CommandWindow = $MW->DialogBox(-title => $VOCP::Strings::Strings{$Lang}{'cmdshell'}  . " $boxnum", -background => $XVOCP::Colors::DefUIAttrib{'background'},
				     -buttons => ["OK"]);
	
	$CommandWindow->Subwidget('B_OK')->configure(%Button_colors);   
	
	my $Instructions = $CommandWindow->Label(-text => $VOCP::Strings::Strings{$Lang}{'cmdshell'}  
						. " $boxnum " 
						. $VOCP::Strings::Strings{$Lang}{'configuration'}, 
						%Label_attribs)->grid(qw/-row 0 -column 0 -columnspan 2/);
	
	
	$CommandWinList = $CommandWindow->Scrolled('Listbox',
				 -font 		=> 'fixed',
				 -width 	=> 25, 
				 -height 	=> 10, 
				 -setgrid 	=> 1,
				 -scrollbars 	=> 'ose',
				 %Listbox_attribs);
	$CommandWinList->grid(qw/-row 1 -columnspan 2 -sticky nsew/);
	$CommandWinList->bind('<Double-1>' => \&editCmd);
	
	my $bts = $CommandWindow->Frame->grid(qw/-row 3 -columnspan 2/);
	my $NewCmdBut = $bts->Button(-text => $VOCP::Strings::Strings{$Lang}{'newcmd'}, -command => \&newCmd)->pack(qw/-side left -expand 1 -fill x/);
	$NewCmdBut->configure(%Button_colors); 
	my $EditCmdBut = $bts->Button(-text => $VOCP::Strings::Strings{$Lang}{'editcmd'}, -command => \&editCmd)->pack(qw/-side left -expand 1 -fill x/);
	$EditCmdBut->configure(%Button_colors); 
	my $DelCmdBut = $bts->Button(-text => $VOCP::Strings::Strings{$Lang}{'delcmd'}, -command => \&delCmd)->pack(qw/-side left -expand 1 -fill x/);
	$DelCmdBut->configure(%Button_colors); 
	
	
	
	refreshCommandList();
	my $result = $CommandWindow->Show();
	
	
	
}

sub editCmd {
	my $tkstuff = shift;
	
	my $selected= $CommandWinList->index('active');
    
   	return undef unless ($selected); # 0th index is ignored
	
	my $selline = $CommandWinList->get($selected);
	
	die "Wierd line in CommandWinList." unless ($selline =~ /^(\d+)/);
	my $selection = $1;
	
	my $command = $Vocp->get_box_command($SelectedCommandBox, $selection, 'UNTAINT');
	
	my $run = $command->{'run'};
	$run =~ s|$Vocp->{'commanddir'}/||g;
	return newCmd($tkstuff, $selection, $command->{'input'}, $command->{'return'},
			$run, $selection);
	 
	
}


sub newCmd {
	my ($tkstuff, $defSelection, $defInput, $defReturn, $defRun, $editCmdSel ) = @_;
	
	#return undef unless ($Vocp->command($SelectedCommandBox, $selection));
	
	
	my ($addCmdSel,$addCmdInput, $addCmdReturn, $addCmdRun);
	
	
	
	my $newCmdWindow = $CommandWindow->DialogBox(-title => $VOCP::Strings::Strings{$Lang}{'cmdtitle'},
			     -buttons => ["OK", "Cancel"],
			     -background => $XVOCP::Colors::DefUIAttrib{'background'});
	$newCmdWindow->Subwidget('B_OK')->configure(%Button_colors);     
	$newCmdWindow->Subwidget('B_Cancel')->configure(%Button_colors);  
	  
	my $labelfrm = $newCmdWindow->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'})->grid(qw/-row 0/);
	my $label = $labelfrm->Label(-text => $VOCP::Strings::Strings{$Lang}{'cmdinst'} . " $SelectedCommandBox\n\n",
					%Label_attribs)->pack(qw/-side left -expand 0 /);

	my $stufffrm =  $newCmdWindow->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'})->grid(qw/-row 1 /);

	$stufffrm->LabEntry(-label => $VOCP::Strings::Strings{$Lang}{'cmdsel'},
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 6,
	     -textvariable => \$addCmdSel,
	     %Labentry_attribs)->pack(-side => "left", -expand => 0);
	     
	$stufffrm->Label(-text => "  " . $VOCP::Strings::Strings{$Lang}{'cmdinput'},
				%Label_attribs)->pack(qw/-side left -expand 0 /);

	my @inputOptions = ('none', 'raw', 'text');
	my $inOptMenu = getOptionMenu($stufffrm, \@inputOptions, \$addCmdInput,%Option_attribs);
	$inOptMenu->configure(%Button_colors);
	$inOptMenu->pack(-side => "left", -expand => 0);
	
			      
	
	##### 2nd row ####
	my $stufffrm2 =  $newCmdWindow->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'})->grid(-row => 2);

	$stufffrm2->Label(-text => "\n".$VOCP::Strings::Strings{$Lang}{'cmdrun'},%Label_attribs)->pack(qw/-side top -expand 0 /);

	
	$stufffrm2->LabEntry(-label => "",
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 30,
	     -textvariable => \$addCmdRun,
	     %Labentry_attribs)->pack(-side => "left", -expand => 0); 

	##### 3rd row #####
	my $stufffrm3 =  $newCmdWindow->Frame(-background => $XVOCP::Colors::DefUIAttrib{'background'})->grid(qw/-row 3 /);
	$stufffrm3->Label(-text => $VOCP::Strings::Strings{$Lang}{'cmdreturn'},%Label_attribs)->pack(qw/-side left -expand 0 /);

	my @outputOptions = sort @VOCP::Vars::Valid_cmd_return_types;
	my $retOptMenu = getOptionMenu($stufffrm3, \@outputOptions, \$addCmdReturn,%Option_attribs);
	$retOptMenu->configure(%Button_colors);
	$retOptMenu->pack(-side => "left", -expand => 0);
	
	
	
	#### Done display ####
	
	#### Set defaults ####
	$addCmdSel =$defSelection || "";
	$addCmdInput = $defInput || 'none';
	$addCmdReturn = $defReturn || 'exit';
	$addCmdRun = $defRun || "";
   
	my $result = $newCmdWindow->Show();
	if ($result =~ /OK/) {
	
		if ($addCmdSel !~ /^\d+$/)
		{
			
			errorBox($newCmdWindow, $VOCP::Strings::Strings{$Lang}{'numselerror'});
			return undef;
		} elsif ($addCmdRun eq "")
		{
			errorBox($newCmdWindow,$VOCP::Strings::Strings{$Lang}{'cmdrunerror'});
			return undef;
		}
	
		if (   (defined $editCmdSel && ($editCmdSel ne $addCmdSel)) # Edit has changed selection num
			|| ( ! defined $editCmdSel ) ) # or this is an Add New...
		{
			# Check if the box exists
			if ( $Vocp->command($SelectedCommandBox, $addCmdSel) )
			{
				#print STDERR "Oye. Selection EXISTS\n";
			
				my $resp = confirmBox($MW, $VOCP::Strings::Strings{$Lang}{'overwritesel'} . $addCmdSel. "?");
    				
				return undef unless ($resp eq 'Ok');
			}
		}
		
		### Check that this is a valid box definition.
		my $olddie = $VOCP::Die_on_error;
		$VOCP::Die_on_error = 1;

		$addCmdSel ||= 'none';
		$addCmdInput ||= 'none';
		$addCmdReturn ||= 'none';
		$addCmdRun ||= 'none';
   		
		
		my $ret = $Vocp->bad_command_definition($SelectedCommandBox, $addCmdSel, $addCmdInput, $addCmdReturn, $addCmdRun );
		
		
		$VOCP::Die_on_error  = $olddie;
		
		if ($ret)
		{
		
			
			print STDERR "eek an error...";
			my $resp = errorBox($newCmdWindow, $VOCP::Strings::Strings{$Lang}{'erroroccur'}."\n$ret");
		       
			return undef;
		}
	
		$Vocp->command($SelectedCommandBox, $addCmdSel, $addCmdInput, $addCmdReturn, $addCmdRun );
		$ChangesMade++;
		if ( defined $editCmdSel && ($editCmdSel ne $addCmdSel) )
		{
			# We've edited a command and changed it's selection num - delete the command selection
			$Vocp->delete_command($SelectedCommandBox, $editCmdSel);
		}
	}
	
	refreshCommandList();
}

sub delCmd {
	my $selected= $CommandWinList->index('active');
    
   	return undef unless ($selected); # 0th index is ignored
	
	my $selline = $CommandWinList->get($selected);
	
	die "Wierd line in CommandWinList." unless ($selline =~ /^(\d+)/);
	my $selection = $1;
	
	return undef unless ($Vocp->command($SelectedCommandBox, $selection));
	
	my $resp = confirmBox($MW, $VOCP::Strings::Strings{$Lang}{'reallydelete'} . $selection . '?',$VOCP::Strings::Strings{$Lang}{'reallydeletetitle'});
	
	return undef unless ($resp eq 'Ok');
	
	$Vocp->delete_command_selection($SelectedCommandBox, $selection);
	$ChangesMade++;
	refreshCommandList();
	
}




	
	
sub refreshCommandList {
	return undef 
		unless (defined $SelectedCommandBox && $Vocp->type($SelectedCommandBox) eq 'command');
	
	my $commands = $Vocp->get_box_commands_list($SelectedCommandBox, 'UNTAINT');
	
	my @com2display;
	$com2display[0] = 'sel    input  return  run';
	foreach my $com (@{$commands})
	{
		my $key = $com->{'selection'};
		my $input = $com->{'input'};
		my $ret = $com->{'return'};
		my $run = $com->{'run'};
		$run =~ s|$Vocp->{'commanddir'}/?||g;
		
		my $string = $key . ' ' x (7 - length($key)) . $input
				. ' ' x (7 - length($input)) . $ret
				. ' ' x (8 - length($ret)) . $run;
		$com2display[scalar @com2display] = $string;
		
	}
	
	$CommandWinList->delete(0, $CommandWinList->index('end'));
	$CommandWinList->insert(0, @com2display);

	return;
}

 
sub save {

	my $saveWindow = $MW->DialogBox(-title => $VOCP::Strings::Strings{$Lang}{'save'}, -background => $XVOCP::Colors::DefUIAttrib{'background'},
			     -buttons => ["OK", "Cancel"]);
			     

	$saveWindow->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -highlightbackground => '#000000');
	#print STDERR Dumper($saveWindow);
	$saveWindow->Subwidget('B_OK')->configure(%Button_colors);
	my $file2save;
	my $labelfrm = $saveWindow->Frame(%Frame_attribs)->grid(qw/-row 0 /);
	my $label = $labelfrm->Label(-text => $VOCP::Strings::Strings{$Lang}{'saveconfig'}. "\n", %Label_attribs )->pack(qw/-side top -expand 0 /);
	
	$labelfrm->LabEntry(-label => "",
	     -labelPack => [-side => "left", -expand => 0],
	     -width => 30,
	     -textvariable => \$file2save,
	     %Labentry_attribs)->pack(-side => "left", -expand => 0);
	
	#### Done display ####
	
	#### Set defaults ####
	$file2save = $BoxConfigFile;
	
	my $result = $saveWindow->Show();
	if ($result =~ /OK/) {
		
		if (! $file2save || ($file2save eq ""))
		{
			errorBox($saveWindow, $VOCP::Strings::Strings{$Lang}{'errorneedfname'});
			
			return undef;
		}
		if (-e $file2save && (! -w $file2save) )
		{
			errorBox($saveWindow, $VOCP::Strings::Strings{$Lang}{'errorcantwrite'}."'$file2save'");
			
			return undef;
		}
		$Vocp->write_box_config($file2save);
		$ChangesMade=0;
	}
	
	return;
}    

sub Exit {
	if ($ChangesMade)
	{
		my $resp = confirmBox($MW, $VOCP::Strings::Strings{$Lang}{'changesmade'});

		return undef unless ($resp eq 'Ok');
	}
	
	exit(0);
	
}


sub getOptionMenu {
	my $widget = shift;
	my $optionsRef = shift;
	my $variableRef = shift;
	my %config = @_;
	
	my $opmen = $widget->Optionmenu(
                              -options => $optionsRef,
                              -variable => $variableRef,
                              -textvariable => $variableRef,
			      %config);
	foreach my $opt (@{$optionsRef})
	{
		#print STDERR "Doing opt for $opt\n";
		$opmen->entryconfigure($opt,%config );
	}
	return $opmen;
}
			      
sub confirmBox {
	my $window = shift;
	my $message = shift;
	my $title = shift || 'Confirmation';
	
	my $dia = $window->Dialog(-title => $title,
				   -text  => $message,
				   -buttons  => ['Ok', 'Cancel'],
				   -bitmap => 'info', 
				   );
						
	$dia->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -highlightbackground => '#000000');
	$dia->Subwidget('B_Ok')->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, 
								-activeforeground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -activebackground => $XVOCP::Colors::DefUIAttrib{'activebackground'});
	$dia->Subwidget('B_Cancel')->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, 
								-activeforeground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -activebackground => $XVOCP::Colors::DefUIAttrib{'activebackground'}); 
	
	
	my $resp = $dia->Show();
	return $resp;
}

sub errorBox {
	my $widget = shift;
	my $message = shift;
	my $title = shift || 'Error';
	
	
	my $dia = $widget->Dialog(-title => $title,
						   -text  => $message,
						   -buttons  => ['Ok'],
						   -bitmap => 'info', 
						   );
						
	$dia->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -highlightbackground => '#000000');
	$dia->Subwidget('B_Ok')->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -foreground => $XVOCP::Colors::DefUIAttrib{'foreground'}, 
								-activeforeground => $XVOCP::Colors::DefUIAttrib{'foreground'}, -activebackground => $XVOCP::Colors::DefUIAttrib{'activebackground'});
	
	my $resp = $dia->Show();
	return $resp;

}

