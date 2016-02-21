#!/usr/bin/perl -w


my $License = join( "\n",  
qq|######################  vocphax.pl #######################|,
qq|####                                                  ####|,
qq|####  Copyright (C) 2003 Pat Deegan, Psychogenic.com  ####|,
qq|####               All rights reserved.               ####|,
qq|####                                                  ####|,
qq|#                                                        #|,
qq|#                 VOCP Fax Viewer and                    #|,
qq|#                       Sender GUI                       #|,
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

VOCPhax - VOCP fax reception/sending GUI

=head1 AUTHOR INFORMATION

LICENSE

    VOCPhax message retrieval GUI, part of the VOCP voice messaging system.
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

Mucho thanks go out to Helene Poirier for designing the GUI.

=cut

############## Tk Libs #############
use Tk 8.0;
use Tk::widgets ;
use Tk::Dialog;
use Tk::DialogBox;
use Tk::Image;
use Tk::Pixmap;
use Tk::Pane;
use Tk::Canvas;
use Tk::FileSelect;
use Tk::JPEG;
use Data::Dumper;
use DirHandle;
use FileHandle;
use File::Copy;


use VOCP::Util;
use VOCP::Vars;
use VOCP::Strings;
use VOCP::PipeHandle;


#use lib '../lib';
use lib '/usr/local/vocp/lib';
use XVOCP;


use strict;

use vars qw {
		$MW
		$Self
		$DefaultTmpDir
		$TmpDir
		$TmpOutQFName
		$Lang
		$Debug
		%menubutton_colors
		%button_colors 
		%scrollbar_attribs
		%listbox_attribs	
		%label_attribs
		%Strings
		$DefaultScale
		$DefaultDir
		$DefaultInQueueDir
		$viewZoomIncrement
		%FileTog3
		$VocpLocalDir
		%ImageCoords 
	
	};



$Debug = 0;

$VocpLocalDir = $VOCP::Vars::Defaults{'vocplocaldir'} || '/usr/local/vocp';

my $envSave = 'DISPLAY|HOSTNAME|UID|EUID|USER|TERM|HOME';
foreach my $envKey (keys %ENV)
{
	if ($envKey =~ m/^($envSave)$/o)
	{
		if ($ENV{$envKey} =~ m|^(.*)$|)
		{	 
			$ENV{$envKey} = $1; # really cheap untain for values we 'trust'
		}
	} else {
	
		delete $ENV{$envKey};
	}
}


$ENV{'PATH'} = '/usr/local/bin/:/usr/bin/:/bin:/usr/X11R6/bin:/usr/local/sbin:/sbin:/usr/sbin';



$viewZoomIncrement = '0.1';
$DefaultScale = '0.25';

$DefaultInQueueDir = '/var/spool/fax/incoming';
$DefaultDir = $DefaultInQueueDir;
$Lang = shift @ARGV || 'en';
unless ($Lang =~ m/^(en|fr)$/)
{
	die "Invalid language $Lang";
}
$Lang = $1;

$DefaultTmpDir = $VOCP::Vars::Defaults{'tempdir'} || '/tmp';
$TmpOutQFName = 'vocpoutq';

my $DefaultOutputColumns = '1725';
my $DefaultOutputRows = '2135';

my %ViewCanvasSize = (
			'width'	=> 640,
			'height'	=> 470,
		);
my %PreviewCanvasSize = (
			'width'	=> 355,
			'height'	=> 220,
		);

my $NoPhonesEntered = '__NOPHONESENTERED__';
	
my $viewIncrement = 15;

%FileTog3 = (
			'gif'	=> 'giftopnm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'bmp'	=> 'bmptoppm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'jpg'	=> 'jpegtopnm | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'jpeg'	=> 'jpegtopnm | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'png'	=> 'pngtopnm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'ps'	=> 'pstopnm   | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'pdf'	=> 'pdftops __FILENAME__ -  | pstopnm | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'eps'	=> 'pstopnm   | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'tiff'	=> 'tifftopnm | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'tif'	=> 'tiftopnm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'xcf'	=> 'xcftopnm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'tga'	=> 'tgatoppm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'xim'	=> 'ximtoppm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			'xpm'	=> 'xpmtoppm  | pnmscale  -xysize __COLS__ __ROWS__ | ppmtopgm | pgmtopbm | pbmtog3',
			
			
		);

my %G3ToFile = ( 
			'gif'	=> 'g32pbm __FILENAME__ |  ppmtogif', 
			'jpg'	=> 'g32pbm __FILENAME__ |  ppmtojpeg',
			'jpeg'	=> 'g32pbm __FILENAME__ |  ppmtojpeg',
			'png'	=> 'g32pbm __FILENAME__ |  pnmtopng',
			'ps'	=> 'g32pbm __FILENAME__ |  pnmtops',
			'pdf'	=> 'g32pbm __FILENAME__ |  pnmtops | ps2pdf - -',
			'eps'	=> 'g32pbm __FILENAME__ |  pnmtops',
			'tiff'	=> 'g32pbm __FILENAME__ |  pnmtotiff',
			'tif'	=> 'g32pbm __FILENAME__ |  pnmtotiff',
			'tga'	=> 'g32pbm __FILENAME__ |  ppmtotga',
			'xpm'	=> 'g32pbm __FILENAME__ |  ppmtoxpm',

		);


my $VERSION = '1.0';

%Strings = (
		'en' => {
				
				'versionblurb'	=> "VOCPhax version $VERSION",
		},
	
			
		'fr'	=> {	
				
				'versionblurb'	=> "VOCPhax version $VERSION",
		},
	);

{

	
	
	open(STDERR, ">/dev/null") unless ($Debug);
	
	$TmpDir = $VOCP::Vars::Defaults{'tempdir'} || (getpwuid($>))[7] ;
	
	if ($TmpDir =~ m|^(.*)$|)
	{
		$TmpDir = $1;
	}
	unless (-w  $TmpDir)
	{
		print STDERR "Can't write to $TmpDir\n"
			if ($Debug);
		$TmpDir = $DefaultTmpDir;
		unless ( -w $TmpDir)
		{
			print STDERR "Can't write to $TmpDir either - aborting.\n";
			exit (1);
		}
	}
	chdir($TmpDir);
	
	print "\n\n$License\n";
	
	
	my $baseTempName = "$TmpDir/$TmpOutQFName";
	my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseTempName);
	unless ($tmpFileHandle && $tmpFileName)
	{
		die "Could not create a temporary out queue dir based on '$baseTempName'";
	}
	
	unlink $tmpFileName;
	$tmpFileHandle->close();
	unless (mkdir $tmpFileName)
	{
		die "Could not create temp out queue dir '$tmpFileName' $!";
	}
	
	$Self = {
			'scale'	=> $DefaultScale,
			'currentdir'	=> $DefaultDir,
			'inqueuedir'	=> $DefaultInQueueDir,
			'lastqueuedir'	=> $DefaultInQueueDir,
			'outqueuedir'	=> $tmpFileName,
			'outputcols'	=> $DefaultOutputColumns,
			'outputrows'	=> $DefaultOutputRows,
			};
			
	init_images();
	init();
	
	
	$Self->{'dialogFactory'} = XVOCP::DialogFactory->new();
	$Self->{'windowGen'} =  XVOCP::WindowGenerator->new(	'parent'	=> $MW,
						);
	
  	$MW->Busy();
	
	previewRefresh($Self->{'inqueuedir'});
	
	$MW->Unbusy();
	
	MainLoop();
	
}






sub init {
	
	%menubutton_colors = %XVOCP::Colors::menubutton_colors;

	%button_colors = %XVOCP::Colors::button_colors;


	%scrollbar_attribs = %XVOCP::Colors::scrollbar_attribs;
	
	%listbox_attribs = %XVOCP::Colors::listbox_attribs;
	
	%label_attribs = %XVOCP::Colors::label_attribs;

	
	$MW = new_mainwindow();
	build_menubar();
	
	
	
}






################################# Preview (Main) Window ######################################
##############################################################################################
##############################################################################################



sub previewRefresh {
	my $directory = shift || $Self->{'currentdir'};
	my $forceRefresh = shift;
	
	$directory =~ s|/$||g;
	my @files;
	if ($forceRefresh || (! $Self->{'previewCache'}->{$directory}))
	{
		$Self->{'previewImagesIdToPos'} = {};
		$Self->{'previews'} = {};
		$Self->{'previewCache'}->{$directory} = []  unless ( $Self->{'previewCache'}->{$directory} );
		$Self->{'imagePreviews'} = [];
		my $dirHandle = DirHandle->new($directory) || return VOCP::Util::error("Could not open $directory: $!");
		
		if ($Self->{'previewCache'}->{$directory})
		{
			my %curContents;
			my %foundContents;
			my $count = 0;
			#print "Cache exists...\n";
			foreach my $ent (@{$Self->{'previewCache'}->{$directory}})
			{
				$curContents{$ent} = $count++;
			}
			
			
			while (my $relfilename = $dirHandle->read())
			{
				next if ($relfilename eq '.' || $relfilename eq '..');
				my $afilename = "$directory/$relfilename";
				next if (-l $afilename || (! -r $afilename));
				
				$foundContents{$afilename} = 1;
				
				if (defined $curContents{$afilename})
				{
					print STDERR "Already know about $afilename\n" if ($Debug);
					next;
				} else {
					$curContents{$afilename} = $count;
					$count++;
					print STDERR "$afilename is new...\n" if ($Debug);
					push @{$Self->{'previewCache'}->{$directory}}, $afilename;
				}
			}
			
			my $numDeleted = 0;
			foreach my $name (keys %curContents)
			{
				unless ($foundContents{$name})
				{
					# this file is gone
					my $idxToDel = $curContents{$name} - $numDeleted;
					$numDeleted++;
					print "$name has been deleted\n" if ($Debug);
					splice @{$Self->{'previewCache'}->{$directory}}, $idxToDel, 1;
				}
			}
		} else {
			
			while (my $relfilename = $dirHandle->read())
			{
				next if ($relfilename eq '.' || $relfilename eq '..');
				my $afilename = "$directory/$relfilename";
				next if (-l $afilename || (! -r $afilename));
				
				push @{$Self->{'previewCache'}->{$directory}}, $afilename;
			}
		}
			
			
		$dirHandle->close();
	
	}
	
	
	my $canvas = $Self->{'faxPreviewCanvas'};
	$canvas->delete('all');
	my $starty = 15;
	my @xcoords = (30, 135, 240);
	my $yincrement = 120;
	$Self->{'imagePreviews'} = [];
	$MW->update();
	
	my $tagBase = $directory;
	$tagBase =~ s/[^\w\d]+//g;
	my $count = 0;
	foreach my $afilename (@{$Self->{'previewCache'}->{$directory}})
	{
		my $image;
		print STDERR "Loading $afilename\n" if ($Debug > 1);
		my $tag = "$tagBase-$count";
		
		#if ($Self->{'previewImagesCache'}->{$tag})
		#{
		#	$image = $Self->{'previewImagesCache'}->{$tag};
		
		#} else {
			my $imageData = getImageData($afilename, '0.05');
			next unless ($imageData);
			$image = $canvas->Pixmap($tag, -data => $imageData);
			$Self->{'previewImagesCache'}->{$tag} = $image;
		#}
		
		
		next unless ($image);
		
		push @{$Self->{'imagePreviews'}}, $afilename;
		
		my $xpos = $xcoords[ $count % 3];
		my $ypos = $starty + ($yincrement * int ($count/3));
		
		
		$canvas->createImage($xpos, $ypos, -image => $tag, -tags => $tag, -anchor => 'nw');
		
		my $cid = $canvas->find('withtag', $tag);
		#$Self->{'previewImagesCache'}->{$cid} = $image;
		
		$Self->{'previewImagesIdToPos'}->{$cid} = $count;
		
		$Self->{'previews'}->{$count}->{'orig'} = {
						'x'	=> $xpos,
						'y'	=> $ypos,
					};
		$canvas->bind($tag, '<Double-1>', sub { previewSelected($tag); });
		$canvas->bind($tag, '<ButtonPress-1>', sub { previewDown($tag); });
		$canvas->bind($tag, '<Motion>', sub { previewDrag($tag); });
		$canvas->bind($tag, '<ButtonRelease-1>', sub { previewRelease($tag, $directory); });
		$MW->update();
		$count++;
		$canvas->configure(-scrollregion=>[0,0,$PreviewCanvasSize{'width'}, int( (($count / 3) + 1) * $yincrement)],,
				-yscrollincrement => 1,
				-xscrollincrement => 1, );
	}
	
	$PreviewCanvasSize{'totalheight'} = int( (($count / 3) + 1) * $yincrement);
	
	
	
	
}



sub export {

	
	#my $str = $Self->{'faxPreviewCanvas'}->postscript();
	#print Dumper $str;
	
}

sub previewExport {
	my $id = $Self->{'selectedPreview'}->{'id'};
	
	return unless (defined $id && defined $Self->{'imagePreviews'}->[$id]);
	
	return doExport($MW, $Self->{'imagePreviews'}->[$id]);
}

sub viewExport {
	
	return unless (defined $Self->{'currentfile'});
	
	return doExport($Self->{'showFaxWindow'}, $Self->{'currentfile'});
}

sub errorBox {
	my $parentWidget = shift;
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

sub ShowAbout {

	
 	$Self->{'windowGen'}->newWindow(			'type'	=> 'about',
								'name'	=> 'about',
								'modal'	=> 1,
								'title'	=> "About VOCPhax",
								#'nodestroy'	=> 1,
					);
	$Self->{'windowGen'}->show('about');				
}


sub ShowVers {

	
 	infoBox($MW, $Strings{$Lang}{'versionblurb'}, "VOCPhax Version");
	
}

sub infoBox {
	my $parentWin = shift || $MW;
	my $message = shift;
	my $title = shift || "Info";
	
	#$Self->{'dialogFactory'}->errorBox($MW, $message, $title);
	$Self->{'windowGen'}->infoWindow(
						'modal'	=> 1,
						'title'	=> $title,
						'parent' => $parentWin,
						'text'	=> $message,
				);
	
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
	
	return $resp;

	
}

sub doExport {
	my $parentWidget = shift || $MW;
	my $fileToConvert = shift || return;
	
	
	my $selectedFile = selectNewFileWindow($parentWidget);
	print STDERR "EXPORT TO $selectedFile\n" if ($Debug);
	return unless ($selectedFile);
	
	
	if ($fileToConvert =~ m#;!|`*{}#)
	{
		return errorBox($parentWidget, "The file to convert ($fileToConvert) has a funny name - aborting." , 
							'No file');
	}
	
	unless (-e $fileToConvert)
	{
		return errorBox($parentWidget, "The file to convert ($fileToConvert) does\nnot seem to exist" , 
							'No file');
	}
	
	unless (-r $fileToConvert)
	{
		return errorBox($parentWidget, "Cannot read the file to convert ($fileToConvert)." , 
							'File unlegible');
	}
	unless ($selectedFile =~ m|.*\.(\w{1,4})$|)
	{
		return errorBox($parentWidget, "You must specify a file type (eg '.jpg') at the end of the file name." , 
							'No file type');
	}
	my $type = $1;
	
	unless (defined $G3ToFile{$type})
	{
		my $supTypes = join (',', keys %G3ToFile);
		return  errorBox($parentWidget, "The specified file type '$type' is unrecognized.\n($supTypes supported)" , 
							'Unknown file type');
	}
	
	
	if (-d $selectedFile)
	{
		return errorBox($parentWidget, "The specified file '$selectedFile' is a directory." , 
							'Directory selected');
	}
	
	if (-e $selectedFile)
	{
		unless (-w $selectedFile)
		{
			return errorBox($parentWidget, "No permission to write to '$selectedFile'." , 
							'Can\'t write');
		}
		
		 
		my $resp = confirmBox($parentWidget, "File '$selectedFile' - exists.  Proceed and overwrite?" , 
							'Overwrite?');
							
		return unless ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'});
		
		unless (unlink $selectedFile)
		{
			return errorBox($parentWidget, "Could not remove existing file '$selectedFile'." , 
							'Can\'t write');
		}
	}
	
	my $exportedFile = FileHandle->new();
	unless ($exportedFile->open($selectedFile, O_WRONLY|O_APPEND|O_CREAT))
	{
		return errorBox($parentWidget, "Could not safely open '$selectedFile'." , 
							'Can\'t write');
	}
	
	my $converter = VOCP::PipeHandle->new();
	my $convStr;
	
	if ($G3ToFile{$type} =~ m/__FILENAME__/) # Need this hack to get around g32pbm's fname weirdness...
	{
		$convStr = $G3ToFile{$type} . ' |';
		$convStr =~ s/__FILENAME__/$fileToConvert/g;
	} else {
		
		$convStr = "cat $fileToConvert | " . $G3ToFile{$type} . ' |';
	}
	
	unless ($converter->open($convStr))
	{
		$exportedFile->close();
		return errorBox($parentWidget, "Could not launch: '$convStr'", 
							'Can\'t convert');
	}
	my $result = join('',$converter->getlines());
	
	$converter->close();
	unless ($result && length($result) > 10)
	{
		$exportedFile->close();
		
		return errorBox($parentWidget, "There was a problem running: '$convStr'", 
							'Can\'t convert');
	}
	
	$exportedFile->print($result);
	
	$exportedFile->close();
	
	return infoBox($parentWidget, "Fax converted to $type", 
							'Success');
}
sub delFile {
	
	my $id = $Self->{'selectedPreview'}->{'id'};
	
	return unless (defined $id && defined $Self->{'imagePreviews'}->[$id]);
	
	my $resp = confirmBox($MW, "Really delete the\n" .$Self->{'imagePreviews'}->[$id] . "\nfile?" , 
							'Really Delete?');
	if ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'})
	{
		delete $Self->{'selectedPreview'}->{'id'};
		my $deleted = unlink $Self->{'imagePreviews'}->[$id];
		
		if ($deleted)
		{
			delete $Self->{'selectedPreview'};
			return previewRefresh($Self->{'lastqueuedir'}, 'FORCEREFRESH');
		} else {
			errorBox($MW, "Could not delete " .$Self->{'imagePreviews'}->[$id] 
									. "$!", 
						'Error');
		}
	}
	
	return;
}
	
	
sub previewDown {
	my $tag = shift;
	
	return unless ($tag =~ m|[\w\d]+-(\d+)$|);
	
	
	my $id = $1;
	
	return unless (defined $Self->{'imagePreviews'}->[$id]);
	
	my $canvas = $Self->{'faxPreviewCanvas'};
	$canvas->delete('myselrect');
	$canvas->raise($tag, 'all');
	my $cx = $canvas->canvasx($Tk::event->x);
	my $cy = $canvas->canvasy($Tk::event->y);
	
	$Self->{'selectedPreview'}->{'mousedown'} = 1;
	$Self->{'selectedPreview'}->{'id'} = $id;
	$Self->{'selectedPreview'}->{'position'} = {
							'x' => $Self->{'previews'}->{$id}->{'orig'}->{'x'},
							'y' => $Self->{'previews'}->{$id}->{'orig'}->{'y'},
					};
	$Self->{'selectedPreview'}->{'mousepos'} = {
							'x' => $cx,
							'y' => $cy,
						};
						
							
}

sub previewDrag {
	my $tag = shift;
	
	return unless ($Self->{'selectedPreview'}->{'mousedown'} && $tag =~ m|-$Self->{'selectedPreview'}->{'id'}|);
	
	my $canvas = $Self->{'faxPreviewCanvas'};
	
	my $cx = $canvas->canvasx($Tk::event->x);
	my $cy = $canvas->canvasy($Tk::event->y);
	
	
	my $xmov = $cx - $Self->{'selectedPreview'}->{'mousepos'}->{'x'};
	my $ymov = $cy - $Self->{'selectedPreview'}->{'mousepos'}->{'y'};
	
	$Self->{'selectedPreview'}->{'mousepos'}->{'y'} = $cy;
	$Self->{'selectedPreview'}->{'mousepos'}->{'x'} = $cx;
	
	
	$Self->{'selectedPreview'}->{'position'}->{'x'} += $xmov;
	$Self->{'selectedPreview'}->{'position'}->{'y'} += $ymov;
	$canvas->coords($tag, $Self->{'selectedPreview'}->{'position'}->{'x'},
				$Self->{'selectedPreview'}->{'position'}->{'y'});
	
	
	if ($Tk::event->y > $PreviewCanvasSize{'windowBottom'} )
	{
		my $ymotion = $Tk::event->y - $PreviewCanvasSize{'windowBottom'};
		$canvas->yviewScroll($ymotion, 'units');
	} elsif ($Tk::event->y < $PreviewCanvasSize{'windowTop'})
	{
		my $ymotion = $Tk::event->y - $PreviewCanvasSize{'windowTop'};
		$canvas->yviewScroll($ymotion, 'units');
	}

		
}

sub previewRelease {
	my $tag = shift;
	my $directory = shift;
	
	my $id = $Self->{'selectedPreview'}->{'id'};
	return unless (defined $id && defined $Self->{'imagePreviews'}->[$id] );
	
	$Self->{'selectedPreview'}->{'mousedown'} = 0;
	
	my $sborder = 5;
	my $curX = $Self->{'selectedPreview'}->{'position'}->{'x'} ;
	my $curY = $Self->{'selectedPreview'}->{'position'}->{'y'};
	if (defined $curX && defined $curY && 
		($curX < 0 || $curX > $PreviewCanvasSize{'width'} || $curY < 0 || $curY > $PreviewCanvasSize{'totalheight'}))
	{
		my $resp = confirmBox($MW, "Really delete the\n" .$Self->{'imagePreviews'}->[$id] . "\nfile?" , 
							'Really Delete?');
		if ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'})
		{
			delete $Self->{'selectedPreview'}->{'id'};
			my $deleted = unlink $Self->{'imagePreviews'}->[$id];
			
			if ($deleted)
			{
				delete $Self->{'selectedPreview'};
				return previewRefresh($Self->{'lastqueuedir'}, 'FORCEREFRESH');
			} else {
				errorBox($MW, "Could not delete " .$Self->{'imagePreviews'}->[$id] 
										. "$!", 
							'Error');
			}
		}
	}
	
	
	
	
	my $selectedItem = $Self->{'previewImagesCache'}->{$tag} ;
	my $itemH = $selectedItem->height();
	my $itemW = $selectedItem->width();
	my $canvas = $Self->{'faxPreviewCanvas'};
	
	my @overlap = $canvas->find('overlapping', $curX, $curY, $curX + $itemW, $curY + $itemH);
	
	if (scalar @overlap == 2)
	{
		my $switchDest = $overlap[0];
		my $switchOrig = $overlap[1];
		
		my $destPos = $Self->{'previewImagesIdToPos'}->{$switchDest};
		my $origPos = $Self->{'previewImagesIdToPos'}->{$switchOrig};
		
		
		
		#print "SD $switchDest ($destPos), SO $switchOrig ($origPos)\n";
		#print "$directory\n";
		#print Dumper($Self->{'previewCache'}->{$directory}->[$origPos]);
		#print Dumper($Self->{'previewCache'}->{$directory}->[$destPos]);
		#print "====================\n";
		
		my $destObj = $Self->{'previewCache'}->{$directory}->[$destPos] ;
		
		
		$Self->{'previewCache'}->{$directory}->[$destPos]
				= $Self->{'previewCache'}->{$directory}->[$origPos];
				
		$Self->{'previewCache'}->{$directory}->[$origPos]
				= $destObj;
			
			
		my $destImgPrev = $Self->{'imagePreviews'}->[$destPos];
		$Self->{'imagePreviews'}->[$destPos] = $Self->{'imagePreviews'}->[$origPos] ;
		$Self->{'imagePreviews'}->[$origPos] = $destImgPrev;
		
		#print Dumper($Self->{'previewCache'}->{$directory}->[$origPos]);
		#print Dumper($Self->{'previewCache'}->{$directory}->[$destPos]);
		#print "====================\n";
		
		
			
		$canvas->coords($switchDest, $Self->{'previews'}->{$origPos}->{'orig'}->{'x'},
				$Self->{'previews'}->{$origPos}->{'orig'}->{'y'});
				
		$canvas->coords($switchOrig, $Self->{'previews'}->{$destPos}->{'orig'}->{'x'},
				$Self->{'previews'}->{$destPos}->{'orig'}->{'y'});
		
		my ($destX, $destY) = ($Self->{'previews'}->{$destPos}->{'orig'}->{'x'},
					$Self->{'previews'}->{$destPos}->{'orig'}->{'y'});
		
		
		
		my $tagStart = $tag;
		unless ($tag =~ m|^([\w\d]+)-\d+$|)
		{
			die "bad tag";
		}
		$tagStart = $1;
		
		my $destTag = "$tagStart-" . $destPos;
		my $origTag = "$tagStart-" . $origPos;
		my $destImg = $Self->{'previewImagesCache'}->{$destTag};
		
		$Self->{'previewImagesCache'}->{$destTag} 
				= $Self->{'previewImagesCache'}->{$origTag};
		$Self->{'previewImagesCache'}->{$origTag}
				= $destImg; 
		
		$canvas->addtag($origTag, 'withtag', $switchDest);
		$canvas->dtag($switchDest, $destTag);
		$canvas->addtag($destTag, 'withtag', $switchOrig);
		$canvas->dtag($switchOrig, $origTag );
		
		$Self->{'selectedPreview'}->{'id'} = $destPos;
		
		$canvas->createRectangle($Self->{'previews'}->{$destPos}->{'orig'}->{'x'} - $sborder, 
				$Self->{'previews'}->{$destPos}->{'orig'}->{'y'} - $sborder,
				$Self->{'previews'}->{$destPos}->{'orig'}->{'x'} + $itemW + $sborder,
				$Self->{'previews'}->{$destPos}->{'orig'}->{'y'} + $itemH + $sborder,
				'-dash' => '.',
				'-tags'	=> 'myselrect')		;
	
		
		######### LAST step ########
		
		
		
		$Self->{'previewImagesIdToPos'}->{$switchDest} = $origPos;
		$Self->{'previewImagesIdToPos'}->{$switchOrig} = $destPos;
		
		
		
		
		###############################
		return;
		
		$Self->{'previews'}->{$destPos}->{'orig'}->{'x'}
				= $Self->{'previews'}->{$origPos}->{'orig'}->{'x'};
		$Self->{'previews'}->{$destPos}->{'orig'}->{'y'}
				= $Self->{'previews'}->{$origPos}->{'orig'}->{'y'};
		
		$Self->{'previews'}->{$origPos}->{'orig'}->{'x'} = $destX;
		$Self->{'previews'}->{$origPos}->{'orig'}->{'y'} = $destY;
		
				
		
		
		
		
		#delete $Self->{'previewCache'}->{$directory};
		#print Dumper($Self->{'previewCache'}->{$directory}->[$Self->{'previewImagesIdToPos'}->{$switchOrig}]);
		#print Dumper($Self->{'previewCache'}->{$directory}->[$Self->{'previewImagesIdToPos'}->{$switchDest}]);
		
		#delete $Self->{'previewImagesCache'};
		
		#return previewRefresh($directory);
		return;
		
	}
	
	$canvas->coords($tag, $Self->{'previews'}->{$id}->{'orig'}->{'x'},
				$Self->{'previews'}->{$id}->{'orig'}->{'y'});
	
	
	$canvas->createRectangle($Self->{'previews'}->{$id}->{'orig'}->{'x'} - $sborder, 
				$Self->{'previews'}->{$id}->{'orig'}->{'y'} - $sborder,
				$Self->{'previews'}->{$id}->{'orig'}->{'x'} + $itemW + $sborder,
				$Self->{'previews'}->{$id}->{'orig'}->{'y'} + $itemH + $sborder,
				'-dash' => '.',
				'-tags'	=> 'myselrect')		;
	
	#delete  $Self->{'selectedPreview'};
	
	return;
}
	

sub previewSelected {
	my $tag = shift;
	
	return unless ($tag =~ m|[\w\d]+-(\d+)$|);
	
	#print "previewSelected $tag\n";
	
	my $id = $1;
	
	return unless (defined $Self->{'imagePreviews'}->[$id]);
	
	#print $Self->{'imagePreviews'}->[$id] . "\n";
	
	my $scale = $Self->{'scale'} || '0.33';
	viewShowFax($Self->{'imagePreviews'}->[$id], $scale);
	
}




sub previewMotion {


	if ($Self->{'previewScroll'})
	{
		#print "Mouse move\n";
		my $canvas = $Self->{'faxPreviewCanvas'};
		#my $cx = $Tk::event->x;
		my $cy = $Tk::event->y;
		#my $xmov = int ($Self->{'previewScrollCoords'}{'x'} - $cx );
		my $ymov = int  ($Self->{'previewScrollCoords'}{'y'} - $cy);
		
		#$Self->{'previewScrollCoords'}{'x'} = $cx;
		$Self->{'previewScrollCoords'}{'y'} = $cy;
		
		#$canvas->xviewScroll($xmov, 'units') if ($xmov != 0);
		$canvas->yviewScroll($ymov, 'units') if ($ymov != 0);
		
	}
	
	
}
sub previewScrollOn {
	#print "Scroll On\n";
	$Self->{'previewScroll'} = 1;
	my $canvas = $Self->{'faxPreviewCanvas'};
	
	$Self->{'previewScrollCoords'}{'x'} = $canvas->canvasx($Tk::event->x);
	$Self->{'previewScrollCoords'}{'y'} = $canvas->canvasx($Tk::event->y);
	
}

sub previewScrollOff {
	#print "Scroll Off\n";
	$Self->{'previewScroll'} = 0;
	my $canvas = $Self->{'faxPreviewCanvas'};
	
	delete $Self->{'previewScrollCoords'}{'x'};
	delete $Self->{'previewScrollCoords'}{'y'};
	
}




sub previewQuit {
	
	my $dirHandle = DirHandle->new($Self->{'outqueuedir'}) ;
	if ($dirHandle)
	{
		my $count = 0;
		my @toDelete;
		while (my $relfilename = $dirHandle->read())
		{
			next if ($relfilename eq '.' || $relfilename eq '..');
			
			my $fullFname =  $Self->{'outqueuedir'} . "/$relfilename";
			next if (-l $fullFname);
			
			push @toDelete, $fullFname;
			$count++;
		}
		
		$dirHandle->close();
		if ($count && ! $Self->{'_outqueuewassent'})
		{
			my $resp = confirmBox($MW, "$count files in out queue not sent - really delete?", 'Files in queue');
			return unless ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'});
			
		}
		unlink @toDelete;
		rmdir $Self->{'outqueuedir'};
	}
	
	$dirHandle = DirHandle->new($TmpDir);
	
	
	if ($dirHandle)
	{
		my $count = 0;
		my @toDelete;
		while (my $relfilename = $dirHandle->read())
		{
			
			next if ($relfilename eq '.' || $relfilename eq '..');
			next unless ($relfilename =~ m|^$TmpOutQFName|);
			
			my $fullFname =  "$TmpDir/$relfilename";
			next unless (-d $fullFname);
			
			push @toDelete, $fullFname;
			
			$count++;
		}
		
		$dirHandle->close();
		if ($count)
		{
			VOCP::Util::log_msg("Deleting tempdirs '" . join(',', @toDelete) . "' during exit cleanup.")
				if ($Debug);
			
			foreach my $tmpDir (@toDelete)
			{
				next unless (-e $tmpDir && -d $tmpDir);
				rmdir $tmpDir;
			}
			
		}
	}
		
	
	exit(0);
}





##################################### Viewer Window ##########################################
##############################################################################################
##############################################################################################


sub viewExit {
	
	return unless ($Self->{'showFaxWindow'});
	
	eval {
		$Self->{'showFaxWindow'}->destroy();
	};
	
	delete $Self->{'showFaxWindow'};
	
}



sub viewXloadImage {
	my $file = shift || $Self->{'currentfile'} || return undef;
	my $scale = shift || $Self->{'scale'};

	$SIG{CHLD} = \&REAPER unless ($SIG{CHLD});
	
	my $child = fork();
	
	if ($child)
	{
		# Parent, do nothing
	} else {
		
		exec("g32pbm $file | pnmscale $scale | xloadimage stdin");
	}
		


}

sub viewXloadImageFullScale {
	my $file = shift || $Self->{'currentfile'} || return undef;
	
	return viewXloadImage($file, 1.0);
	
}

sub viewZoomTo {
	my $newScale = shift;
	
	return unless ($newScale && $newScale =~ /^\d+$/);
	
	$newScale /= 100;
	
	#my $canvas = $Self->{'faxPreviewCanvas'} ; 
	#$canvas->scale('faxImage', 0, 0, $newScale, $newScale)
       
	viewShowFax($Self->{'currentfile'}, $newScale);
	
}


sub viewZoomIn {
	
	return undef unless ($Self->{'currentfile'});
	
	my $scale = $Self->{'scale'} + $viewZoomIncrement;
	
	if ($scale > 3)
	{
		$scale = 3;
	}
	
	$Self->{'scale'} = $scale;
	
	#my $canvas = $Self->{'faxPreviewCanvas'} ; 
	#$canvas->scale('faximage', 0, 0, $scale, $scale)
       
	viewShowFax($Self->{'currentfile'}, $Self->{'scale'});
	
}


sub viewZoomOut {
	
	return undef unless ($Self->{'currentfile'});
	
	my $scale = $Self->{'scale'} - $viewZoomIncrement;
	
	if ($scale < 0.1)
	{
		$scale = 0.1;
	}
	
	$Self->{'scale'} = $scale;
	
	viewShowFax($Self->{'currentfile'}, $Self->{'scale'});
	
}


sub viewMotion {


	if ($Self->{'viewScroll'})
	{
		#print "Mouse move\n";
		my $canvas = $Self->{'viewCanvas'};
		my $cx = $Tk::event->x; #$canvas->canvasx($Tk::event->x);
		my $cy = $Tk::event->y; # $canvas->canvasx($Tk::event->y);
		#print "($cx, $cy)\n";
		my $xmov = ($Self->{'viewScrollCoords'}{'x'} - $cx );
		my $ymov = ($Self->{'viewScrollCoords'}{'y'} - $cy) ;
		
		$Self->{'viewScrollCoords'}{'x'} = $cx;
		$Self->{'viewScrollCoords'}{'y'} = $cy;
		
		$canvas->xviewScroll($xmov, 'units');
		$canvas->yviewScroll($ymov, 'units');
		
	}
	
	
}
sub viewScrollOn {
	#print "Scroll On\n";
	$Self->{'viewScroll'} = 1;
	my $canvas = $Self->{'viewCanvas'};
	$canvas->configure( -cursor => 'diamond_cross');
	
	$Self->{'viewScrollCoords'}{'x'} = $Tk::event->x; #$canvas->canvasx($Tk::event->x);
	$Self->{'viewScrollCoords'}{'y'} = $Tk::event->y; #$canvas->canvasx($Tk::event->y);
	
}

sub viewScrollOff {
	#print "Scroll Off\n";
	$Self->{'viewScroll'} = 0;
	my $canvas = $Self->{'viewCanvas'};
	$canvas->configure( -cursor => 'crosshair');
	
	delete $Self->{'viewScrollCoords'}{'x'};
	delete $Self->{'viewScrollCoords'}{'y'};
	
}




sub viewAddToQueue {
	my $file = shift || $Self->{'currentfile'};
	
	
	
	my $baseTempName;
	
	#### KLUDGE - Seems g32pbm is acting on info contained in FILENAME!!!
	#### Ugh.  
	if ($file =~ m|.*/([^/-]+)[^/]*$|)
	{
		$baseTempName = $Self->{'outqueuedir'} . "/$1" . "-vocpfout$$";
	} else {
		$baseTempName = $Self->{'outqueuedir'} . "/vocpfaxout$$";
	}
	
	my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseTempName, 'g3');
	unless ($tmpFileHandle && $tmpFileName)
	{
		errorBox($Self->{'showFaxWindow'}, "Could not create tmp file based on $baseTempName", 'Error');
		return;
	}
	
	
	copy($file, $tmpFileHandle);
	
	$Self->{'_outqueuewassent'} = 0;
	$tmpFileHandle->close();
	$Self->{'lastqueuedir'} = $Self->{'outqueuedir'};
	previewRefresh($Self->{'outqueuedir'}, 'FORCEREFRESH');
	
	infoBox($Self->{'showFaxWindow'}, "Fax added to queue - send when ready.", 'Done');
	
	
	
	return;
}


sub send {
	my $parentWidget = shift || $MW;
	
	my $queuedir = $Self->{'outqueuedir'} || return;
	
	my $toSend = getFilesInDir($queuedir);
	
	unless ($toSend && scalar @{$toSend})
	{
		return errorBox($parentWidget, "No files to send in outgoing queue.", 'No files');
	}
	
	$Self->{'destphonenums'} = '';
	
	
	my $resp = new_phonenum_window($parentWidget);
	
	if ($resp  == $XVOCP::WindowGenerator::Action{'CONFIRM'})
	{
		AcceptPhoneNums();
	} else {
		return;
	}
	#$parentWidget->waitVariable(\$Self->{'destphonenums'});
	
	
	return unless ( $Self->{'destphonenums'} && ref $Self->{'destphonenums'} && ref $Self->{'destphonenums'} eq 'ARRAY');
	
	my @destPhones;
	foreach my $num (@{$Self->{'destphonenums'}})
	{
		next unless ($num =~ m|^([\d\sA-Da-d]+)$|);
		$num = uc($num);
		$num =~ s/[^\dA-D]//g;
		#print "Extracted number '$num'\n";
		push @destPhones, $num;
	}
	
	#### Check that nothing has changed in our queue.
	$toSend = getFilesInDir($queuedir);
	
	unless ($toSend && scalar @{$toSend})
	{
		return errorBox($parentWidget, "No files to send in outgoing queue.", 'No files');
	}
	
	my $files2Send = join(' ', @{$toSend});
	my $username = (getpwuid($>))[0];
	my $pageCount = scalar @{$toSend};
	my $destCount = 0;
	foreach my $faxDestination (@destPhones)
	{
		my $faxspoolHandle = VOCP::PipeHandle->new();
		# We could multicast but 1 job per destination may be easier to track and catch errors etc.
		my $openStr = "faxspool -A 'VOCPhax sent by $username' $faxDestination $files2Send |";
		
		unless ($faxspoolHandle->open($openStr))
		{
			errorBox($parentWidget, "Could not open faxspool", 'No faxspool');
			next;
		}
		
		$parentWidget->update();
		
		my $output = join('', $faxspoolHandle->getlines());
		
		#print "OUTPUT '$output'\n";
		
		$parentWidget->update();
		$faxspoolHandle->close();
		
		$destCount++;
	}


	
	$Self->{'_outqueuewassent'} = 1;
	return infoBox($parentWidget, scalar @{$toSend} . " pages spooled for $destCount destinations", 'Fax Spooled');
}
	

sub viewShowFax {
	my $selectedFile = shift || return undef;
	my $scale = shift || $Self->{'scale'};
	
	#delTempFile();
	
	$Self->{'currentfile'} = $selectedFile;
	$Self->{'scale'} = $scale;
	
	$MW->Busy(-recurse => 1);
	unless ($Self->{'showFaxWindow'})
	{
		previewScrollOff();
		$Self->{'showFaxWindow'} = new_viewwindow();
	}
	
	eval {
		$Self->{'showFaxWindow'}->Width();
	};
	
	if ($@)
	{
		delete $Self->{'showFaxWindow'};
		previewScrollOff();
		return viewShowFax($selectedFile, $scale);
		
	}
	
	$Self->{'showFaxWindow'}->Busy(-recurse => 1);
	
	my $imageData = getImageData($selectedFile, $scale);
	
	unless (defined $imageData)
	{
		$MW->Unbusy();
		$Self->{'showFaxWindow'}->Unbusy();
		return;
	}
	$MW->update();

	#my $FaxImage = $MW->Pixmap('faximage', -data => $imageData);
	
	
	my $canvas = $Self->{'viewCanvas'} ; 
 	$canvas->delete('all');
	$Self->{'showFaxWindow'}->update();
	$Self->{'faxImage'} = $canvas->Pixmap('faximage', 
			-data => $imageData);
  
	my $w=$Self->{'faxImage'}->width() + 30;
	my $h=$Self->{'faxImage'}->height() + 30;
	
	$canvas->createImage(15,15,-image => 'faximage',-anchor=>"nw");
	$canvas->configure(-scrollregion=>[0,0,$w,$h],
				-yscrollincrement => 1,
				-xscrollincrement => 1,);
	if ($w < $ViewCanvasSize{'width'})
	{
		my $diff = int ( ($w - $ViewCanvasSize{'width'})/2);
		$canvas->xviewMoveto(1);
		$canvas->xviewScroll($diff, 'units');

	}
	$Self->{'showFaxWindow'}->Unbusy();
	
	$MW->Unbusy();
	
	return;
}
	




	
##################################### Either Window ##########################################
##############################################################################################
##############################################################################################


sub view {
	
	my $directory = $Self->{'currentdir'};
	
	my $selectedFile = selectFileWindow($MW, $directory) || return undef;

	delTempFile();
	
	viewShowFax($selectedFile);

}




sub create {
	my $directory = $Self->{'currentdir'};
	
	my $selectedFile = selectFileWindow($MW, $directory) || return undef;
	delTempFile();
	
	
	
	if ($selectedFile !~ m|\.(\w{1,4})$|)
	{
		errorBox($MW, "Can't read determine file type for $selectedFile", 'Not Found');
		return;
	}
	
	my $type = $1;
	
	unless (defined $FileTog3{$type})
	{
		errorBox($MW, "Don't have a file converter for $type ($selectedFile)", 'Not Found');
		return;
	}
	
	my $baseTempName = "$TmpDir/vocpfax$$";
	
	my ($tmpFileHandle, $tmpFileName) = VOCP::Util::safeTempFile($baseTempName, 'g3');

	unless ($tmpFileHandle && $tmpFileName)
	{
		errorBox($MW, "Could not create a safe tempfile based on '$baseTempName'", 'Error');
		return;
	}
	
	$tmpFileHandle->autoflush();
	$Self->{'tempfile'} = $tmpFileName;
	
	$MW->Busy(-recurse => 1);
	
	my $g3Converter = VOCP::PipeHandle->new();
	my $openStr;
	
	if ($FileTog3{$type} =~ m/__FILENAME__/)
	{
		$openStr = "$FileTog3{$type} |";
		$openStr =~ s/__FILENAME__/$selectedFile/;
	} else {
	
	 	$openStr = "cat $selectedFile | $FileTog3{$type} |";
	}
	
	$openStr =~ s/__COLS__/$Self->{'outputcols'}/;
	$openStr =~ s/__ROWS__/$Self->{'outputrows'}/;
	
	
	
	unless ($g3Converter->open($openStr))
	{
		errorBox($MW, "Could not open pipe to $openStr", 'No pipe');
		return;
	}
	
	my $g3Data = join('', $g3Converter->getlines());
	$g3Converter->close();
	
	$tmpFileHandle->print($g3Data);
	
	$tmpFileHandle->close();
	$MW->Unbusy();
	viewShowFax($tmpFileName);

}
	
	






################################# Utility funcs ######################################
######################################################################################
######################################################################################


sub delTempFile {
	
	if ($Self->{'tempfile'})
	{
		if (-e $Self->{'tempfile'} && -w $Self->{'tempfile'} && $Self->{'tempfile'} =~ m|^$TmpDir/vocpfax|)
		{
			unlink $Self->{'tempfile'};
			delete $Self->{'tempfile'};
		}
	}
}

	
sub getImageData {
	my $file = shift || return undef;
	my $scale = shift ||  $Self->{'scale'};
	
	$file =~ s|//|/|g;
	
	print STDERR "getImageData ($file, $scale) called\n" if ($Debug);
	return $Self->{'cache'}->{$file}->{$scale} 
		if (defined $Self->{'cache'}->{$file}->{$scale});
	
	print STDERR "getImageData() Converting file\n" if ($Debug > 1);
	unless ($scale =~ m|^([\d\.]+)$|)
	{
		return VOCP::Util::error("getImageData - invalid scale passed '$scale'");
	}
	
	$scale = $1;
	
	unless ($file =~ m#^([^;|`*!]+)$#) 
	{
		return VOCP::Util::error("getImageData - invalid filename passed '$file'");
	}
	$file = $1;
	
	my $converter = VOCP::PipeHandle->new();
	
	my $runStr = "g32pbm $file | pnmscale $scale | ppmtoxpm |";
	
	if (! $converter->open($runStr))
	{
		VOCP::Util::log_msg("Could not open 'g32pbm $file | pnmscale $scale'");
		return undef;
	}
	
	my $data = join('', $converter->getlines());
	
	$converter->close();
	
	return undef unless ($data);
	
	unless ($data =~ /^(.+)$/sm)
	{
		die "Problem with converted image data...";
	} 
	$data = $1; # Cheap untaint here...
	$Self->{'cache'}->{$file}->{$scale} = $data;
	return $data;
}




sub emptyDir {
	my $dir = shift || return;
	my $whichqueue = shift;
	
	my $toDelete = getFilesInDir($dir);
	
	return unless ($toDelete);
	my $numFiles = scalar @{$toDelete};
	return unless ($numFiles);
	
	
	my $resp = confirmBox($MW, "Really delete the $numFiles files\nin $dir?", "Really Delete?");
	
	return unless ($resp == $XVOCP::WindowGenerator::Action{'CONFIRM'});
	
	my $numDel = unlink @{$toDelete};
	
	infoBox($MW, "$numDel files deleted", "Done");
	
	my $queuedir = $whichqueue . 'queuedir';
	$Self->{'lastqueuedir'} =  $Self->{$queuedir};
	previewRefresh($Self->{$queuedir}) if (defined $Self->{$queuedir});
	return;
}

sub getFilesInDir {
	my $directory = shift || return;
	
	
	my @filesPresent;
	if ($Self->{'previewCache'}->{$directory})
	{
		foreach my $file (@{$Self->{'previewCache'}->{$directory}})
		{
			push @filesPresent, $file;
		}
	} else {
	
		my $dirHandle = DirHandle->new($directory);
	
		unless ($dirHandle)
		{
			errorBox($MW, "Could not open director $directory $!", 'Can\'t open');
			return;
		}
	
		while (my $relfilename = $dirHandle->read())
		{
			next if ($relfilename eq '.' || $relfilename eq '..');
			my $fullFname =  "$directory/$relfilename";
			next if (-l $fullFname);
			push @filesPresent, $fullFname;
		}
		
		$dirHandle->close();
	}
	
	return \@filesPresent;
}
################################# Windowing ##########################################
######################################################################################
######################################################################################


sub new_phonenum_window {


	my $temp_win = $Self->{'windowGen'}->newWindow(		'type'	=> 'sendfax',
								'name'	=> 'sendfax',
								'modal'	=> 1,
								'title'	=> "Send faxes",
								#'nodestroy'	=> 1,
					);
	
	
	
	#my $temp_win = $MW->Toplevel(-title=>'xVOCP 1.0',
	#				-background => '#09557B',
	#				-borderwidth => 0,
	##				-relief => 'flat',
	#				-height => 343,
	#				-width => 456,);
					
					#-buttons  => ['Ok'],);
					
	$Self->{'phonenumWindow'} = $temp_win;
	$Self->{'destnumberStrings'} = [];
	$Self->{'destnumbers'} = [];
	
	$Self->{'phonenumAdd'} = '';	
	$Self->{'phonenumListBox'} = $temp_win->Scrolled('Listbox', 
		-width => '18',
		-height => '4',
		-font => 'fixed -12',
		-scrollbars => 'oe',
		-relief => 'flat',
		%XVOCP::Colors::listbox_attribs,
	)->place(
		-x => '34',
		-y => '76',
	);
	
	my $numEntry = $temp_win->Entry(
			%XVOCP::Colors::listbox_attribs,
			%XVOCP::Colors::textentry_attribs,
			-font => 'fixed -12',
			-width => '15',
			-relief => 'groove',
			-textvariable => \$Self->{'phonenumAdd'},
	)->place(
		-x => '34',
		-y => '51',
	);
	
	$numEntry->bind('<Return>', \&AddPhoneNum);
	
	my $addImg = $temp_win->Photo('add', -file =>$XVOCP::Images{'add'}, -format => 'jpeg');
	my $addlabel = $temp_win->Label(-image => $addImg, 
					-takefocus => 1,
					%XVOCP::Colors::labelInv_attribs
					)->place(
						-x => 190,
						-y => 53,
					);
	$addlabel->bind('<ButtonRelease-1>', \&AddPhoneNum);
	
	my $rmImg = $temp_win->Photo('remove', -file =>$XVOCP::Images{'remove'}, -format => 'jpeg');
	my $rmlabel = $temp_win->Label(-image => $rmImg, 
					-takefocus => 1,
					%XVOCP::Colors::labelInv_attribs
					)->place(
						-x => 190,
						-y => 130,
					);
	$rmlabel->bind('<ButtonRelease-1>', \&RmPhoneNum);
	
	
	
	$Self->{'windowGen'}->show('sendfax');
	my $resp = $Self->{'windowGen'}->action();
	return $resp;
}
sub AddPhoneNum {

	my $num = $Self->{'phonenumAdd'};
	my $cleanNum = uc($num);
	$cleanNum =~ s/[^\d]+//g;
	unless ($cleanNum =~ /\d{6,13}/)
	{
		return errorBox($Self->{'phonenumWindow'}, "Invalid phone number $num", 'Bad number');
	}
	#my $selected = $Self->{'messageListbox'}->get('active');
	push @{$Self->{'destnumbers'}}, $cleanNum;
	push @{$Self->{'destnumberStrings'}}, $num;
	
	$Self->{'phonenumAdd'} = '';
	
	refreshPhoneList();
	
	return;
}

sub RmPhoneNum {
	
	my $selected = $Self->{'phonenumListBox'}->get('active') || return;
	#print "SELECTED IS $selected\n";
	if ($selected =~ m/^(\d+)\s/)
	{
		my $id = $1;
		$id -= 1;
		#print "ID is $id\n";
		splice @{$Self->{'destnumbers'}}, $id, 1 ;
		splice @{$Self->{'destnumberStrings'}}, $id, 1;
		refreshPhoneList();
	}
	return;
}


sub refreshPhoneList {
	my @displayStrings;
	my $count = 1;
	foreach my $dnum (@{$Self->{'destnumberStrings'}})
	{
		push @displayStrings, $count++ . "  $dnum";
	}
	$Self->{'phonenumListBox'}->delete(0,'end');
	$Self->{'phonenumListBox'}->insert(0, @displayStrings);
	
	return;
}

sub AcceptPhoneNums {
	
	
	$Self->{'destphonenums'} = $Self->{'destnumbers'};
	
	
	delete $Self->{'phonenumWindow'};
	delete $Self->{'phonenumText'};
	return;
}
	

sub new_viewwindow {
	
		
	my $temp_win = $MW->Toplevel(-title=>'xVOCP 1.0',
					-background => '#09557B',
					-borderwidth => 0,
					-relief => 'flat',
					-height => 343,
					-width => 456,);
					
					#-buttons  => ['Ok'],);
	$temp_win->iconname('vocphaxview');
	my $xpm = $temp_win->Photo('vocphaxview');
	$xpm->read("$VocpLocalDir/images/callcenter/vocplogo.xpm");
	$temp_win->iconimage($xpm);
	
	$temp_win->configure( %label_attribs);	
	
	$temp_win->geometry("750x600+0+0");
	$temp_win->wm("minsize" => 750, 600);
	#my $bgimage = $temp_win->Pixmap('viewBgImage', -file => "/usr/local/vocp/images/xvocpmain.xpm");
	my $bgimage = $temp_win->Photo('viewBgImage', -file => "$VocpLocalDir/images/vocphax/vocphax_viewer.jpg", -format => 'jpeg');
	my $imglabel = $temp_win->Label(-image => $bgimage, -bg => '#09557B')->place(
						-x => 0,
						-y => 0,
						);
	
	
	
	for (my $i = 4; $i <=7; $i++)
	{
		my $imgname = "image0$i";
		$Self->{'images'}->{$imgname} = 
					$temp_win->Photo($imgname, -file => "$VocpLocalDir/images/vocphax/".$ImageCoords{$i}{'name'}, 
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
				$temp_win->Photo($imgname, -file => "$VocpLocalDir/images/vocphax/".$ImageCoords{$i}{'mouseover'},
							 -format => 'jpeg');
		}
					
		
		
	}
	
	
	$Self->{'buttons'}->{5}->bind('<Enter>', sub { changeImage(5 , 'on');});	
	$Self->{'buttons'}->{5}->bind('<Leave>', sub { changeImage(5, 'off');});
	
	$Self->{'buttons'}->{6}->bind('<Enter>', sub { changeImage(6 , 'on');});	
	$Self->{'buttons'}->{6}->bind('<Leave>', sub { changeImage(6, 'off');});
	
	$Self->{'buttons'}->{7}->bind('<Enter>', sub { changeImage(7 , 'on');});	
	$Self->{'buttons'}->{7}->bind('<Leave>', sub { changeImage(7, 'off');});
	
	$Self->{'buttons'}->{5}->bind('<FocusIn>', sub { changeImage(5 , 'on');});	
	$Self->{'buttons'}->{5}->bind('<FocusOut>', sub { changeImage(5, 'off');});
	
	$Self->{'buttons'}->{6}->bind('<FocusIn>', sub { changeImage(6 , 'on');});	
	$Self->{'buttons'}->{6}->bind('<FocusOut>', sub { changeImage(6, 'off');});
	
	$Self->{'buttons'}->{7}->bind('<FocusIn>', sub { changeImage(7 , 'on');});	
	$Self->{'buttons'}->{7}->bind('<FocusOut>', sub { changeImage(7, 'off');});
	
	

	my $c=$temp_win->Scrolled('Canvas',
					-width => $ViewCanvasSize{'width'},
					-height => $ViewCanvasSize{'height'},
					-scrollregion => [0, 0, 50, 60],
					-scrollbars=>"ose",
					-confine=>1, 
					-yscrollincrement => 1,
					-xscrollincrement => 1,
					-takefocus => 1)->place(-x => 55, -y => 55);
	my $canvas=$c->Subwidget("canvas");
	
	$canvas->configure(-background => $XVOCP::Colors::DefUIAttrib{'background'}, -cursor => 'crosshair');
	$canvas->Tk::bind('<ButtonPress-1>', \&viewScrollOn);
	$canvas->Tk::bind('<Motion>', \&viewMotion);
	
	$canvas->Tk::bind('<ButtonRelease-1>', \&viewScrollOff);
	#$canvas->Tk::bind('<Leave>', \&viewScrollOff);
	
	#$c->Subwidget('listbox')->configure(%XVOCP::Colors::listbox_attribs);
	$c->Subwidget('xscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$c->Subwidget('yscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$c->Subwidget('corner')->configure(%XVOCP::Colors::label_attribs);
	$Self->{'viewCanvas'} = $canvas;
	
	#my $resp = $temp_win->Show();
	build_viewer_menu($temp_win);
	return $temp_win;
}


sub new_mainwindow {
	
	my $temp_win = Tk::MainWindow->new(
	
					'-title' => 'VOCPhax 1.0',
					'-background' => '#09557B',
					'-borderwidth' => '0',
					'-relief' => 'flat',
					'-height' => 385,
					'-width' => 456);
	
	$temp_win->iconname('vocphax');
	my $xpm = $temp_win->Photo('vocphax');
	$xpm->read("$VocpLocalDir/images/vocphax/vocphax.xpm");
	$temp_win->iconimage($xpm);
	
	
	$temp_win->configure( %label_attribs);
	$temp_win->geometry("456x385");	
	#my $bgimage = $temp_win->Pixmap('bgimage', -file => "/usr/local/vocp/images/xvocpmain.xpm");
	
	my $bgimage = $temp_win->Photo('bgimage', -file => "$VocpLocalDir/images/vocphax/vocphax_preview.jpg", -format => 'jpeg');
		my $imglabel = $temp_win->Label(-image => $bgimage, -bg => '#09557B')->place(
						-x => 0,
						-y => 0,
						);
	$PreviewCanvasSize{'windowTop'} = 42;
	$PreviewCanvasSize{'windowBottom'} = $PreviewCanvasSize{'windowTop'} + $PreviewCanvasSize{'height'};
	
	$PreviewCanvasSize{'totalheight'} = $PreviewCanvasSize{'height'};
	my $c=$temp_win->Scrolled('Canvas',
					-width => $PreviewCanvasSize{'width'},
					-height => $PreviewCanvasSize{'height'},
					-scrollregion => [0, 0, 50, 60],
					-scrollbars=>"ose",
					-confine=>1,
					-takefocus => 1)->place(-x => 50, -y => $PreviewCanvasSize{'windowTop'});
	my $canvas=$c->Subwidget("canvas");
	
	$canvas->configure(-background => $XVOCP::Colors::DefUIAttrib{'background'});
	
	$c->Subwidget('xscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$c->Subwidget('yscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$c->Subwidget('corner')->configure(%XVOCP::Colors::label_attribs);
	
	
	for (my $i = 1; $i <=3; $i++)
	{
		my $imgname = "image0$i";
		$Self->{'images'}->{$imgname} = 
					$temp_win->Photo($imgname, -file => "$VocpLocalDir/images/vocphax/".$ImageCoords{$i}{'name'}, 
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
				$temp_win->Photo($imgname, -file => "$VocpLocalDir/images/vocphax/".$ImageCoords{$i}{'mouseover'},
							 -format => 'jpeg');
		}
					
		
		
	}
	
	$Self->{'buttons'}->{2}->bind('<Enter>', sub { changeImage(2 , 'on');});	
	$Self->{'buttons'}->{2}->bind('<Leave>', sub { changeImage(2, 'off');});
	
	$Self->{'buttons'}->{3}->bind('<Enter>', sub { changeImage(3 , 'on');});	
	$Self->{'buttons'}->{3}->bind('<Leave>', sub { changeImage(3, 'off');});
	
	$Self->{'buttons'}->{2}->bind('<FocusIn>', sub { changeImage(2 , 'on');});	
	$Self->{'buttons'}->{2}->bind('<FocusOut>', sub { changeImage(2, 'off');});
	
	$Self->{'buttons'}->{3}->bind('<FocusIn>', sub { changeImage(3 , 'on');});	
	$Self->{'buttons'}->{3}->bind('<FocusOut>', sub { changeImage(3, 'off');});
	
	
	$Self->{'faxPreviewCanvas'} = $canvas;
	
	return $temp_win;
}
sub resetMainImages {
	
	for(my $i=1; $i<=3; $i++)
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


sub init_images {


	%ImageCoords = (
			1	=> {
					'x'	=> 197,
					'y'	=> 17,
					'name'	=> 'vocphax_title.jpg',
				},
			2	=> {
					'x'	=> 137,
					'y'	=> 299,
					'name'	=> 'l_inbox.jpg',
					'mouseover'	=> 'l_inbox_over.jpg',
					'method'=> \&_prevInqueue,
				},
			3	=> {
					'x'	=> 266,
					'y'	=> 299,
					'name'	=> 'l_outbox.jpg',
					'mouseover'	=> 'l_outbox_over.jpg',
					'method'=> \&_prevOutqueue,
				},
				
		
			4	=> {
					'x'	=> 340,
					'y'	=> 17,
					'name'	=> 'vocphax_title.jpg',
				},
			5 	=> {
					'x'	=> 218,
					'y'	=> 564,
					'name'	=> 'l_zoomin.jpg',
					'mouseover'	=> 'l_zoomin_over.jpg',
					'method'=> \&viewZoomIn,
				},
			6 	=> {
					'x'	=> 330,
					'y'	=> 564,
					'name'	=> 'l_zoomout.jpg',
					'mouseover'	=> 'l_zoomout_over.jpg',
					'method'=> \&viewZoomOut,
				},
			7 	=> {
					'x'	=> 455,
					'y'	=> 564,
					'name'	=> 'l_addtoqueue.jpg',
					'mouseover'	=> 'l_addtoqueue_over.jpg',
					'method'=> sub { viewAddToQueue(); },
				},


	);
	
	
}

sub _prevInqueue { 
	$Self->{'lastqueuedir'} = $Self->{'inqueuedir'}; 
	previewRefresh($Self->{'inqueuedir'}, 'FORCEREF'); 
}
sub _prevOutqueue {
	$Self->{'lastqueuedir'} = $Self->{'outqueuedir'}; 
	previewRefresh($Self->{'outqueuedir'}, 'FORCEREF'); 
}

sub help {
	
	
	$Self->{'windowGen'}->helpWindow(
							'modal'	=> 0,
							'title'	=> "Help",
							'file' =>"$VocpLocalDir/doc/faxes.txt",
							'forceuntaint'	=> 1,
							
					);

	return;
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
	my $file = $menubar->cascade(-label =>'~'. $VOCP::Strings::Strings{$Lang}{'file'} || 'file' , -tearoff =>0, %menubutton_colors);
	
	$file->menu->configure( %menubutton_colors);
	$file->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'open'}  || 'open') . '...',  %menubutton_colors,
			-command => \&view);
	
			
	$file->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'create'}  || 'create') . '...' ,  %menubutton_colors,
			-command => \&create);

	$file->separator();
	
	$file->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'export'}  || 'export...') ,  %menubutton_colors,
			-command => \&previewExport);

	
	$file->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'delete'}  || 'delete') . '...' ,  %menubutton_colors,
			-command => \&delFile);

	
	$file->separator();
	$file->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'sendqueue'}  || 'sendqueue') . '...' ,  %menubutton_colors,
			-command => \&send);

	my $separator = $file->separator();
	
	#$separator->configure(-background => '#156187', -foreground => '#55A1C7');
	
	$file->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'quit'}  || 'quit') ,  %menubutton_colors,
			-command => \&previewQuit);
			

	
	
	
	### In Queue menu
	my $inq = $menubar->cascade(-label => $VOCP::Strings::Strings{$Lang}{'inqueue'} || 'inqueue' , -tearoff =>0, %menubutton_colors);
	$inq->menu->configure( %menubutton_colors);
	$inq->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'preview'}  || 'preview'),  %menubutton_colors,
			-command => \&_prevInqueue);
	
	$inq->command(-label => ($VOCP::Strings::Strings{$Lang}{'selectdir'}  || 'selectdir'),  %menubutton_colors,
			-command => sub { 
					$Self->{'inqueuedir'} = selectFileWindow($MW, $Self->{'inqueuedir'}, 'SELDIR') 
									||  $Self->{'inqueuedir'};
					$Self->{'lastqueuedir'} = $Self->{'inqueuedir'};
					 previewRefresh($Self->{'inqueuedir'}, 'FORCEREF'); });
	
	$inq->separator();
	
	$inq->command(-label => ($VOCP::Strings::Strings{$Lang}{'emptyqueue'}  || 'emptyqueue'),  %menubutton_colors,
			-command => sub { emptyDir($Self->{'inqueuedir'}, 'in'); });
	
	
	### Out queue menu
	my $outq = $menubar->cascade(-label => $VOCP::Strings::Strings{$Lang}{'outqueue'} || 'outqueue' , -tearoff =>0, %menubutton_colors);
	$outq->menu->configure( %menubutton_colors);
	
	$outq->command(-label => ($VOCP::Strings::Strings{$Lang}{'preview'}  || 'preview'),  %menubutton_colors,
			-command => \&_prevOutqueue );
	
	
	$outq->command(-label => ($VOCP::Strings::Strings{$Lang}{'selectdir'}  || 'selectdir'),  %menubutton_colors,
			-command => sub {
					$Self->{'origoutqueuedir'} = $Self->{'outqueuedir'} unless ($Self->{'origoutqueuedir'}) ;
					$Self->{'outqueuedir'} = selectFileWindow($MW, $Self->{'outqueuedir'}, 'SELDIR') 
									||  $Self->{'outqueuedir'};
					$Self->{'lastqueuedir'} = $Self->{'outqueuedir'};
					
					 previewRefresh($Self->{'outqueuedir'}, 'FORCEREF'); });
	
	$outq->separator();
	
	$outq->command(-label => ($VOCP::Strings::Strings{$Lang}{'emptyqueue'}  || 'emptyqueue'),  %menubutton_colors,
			-command => sub { emptyDir($Self->{'outqueuedir'}, 'out'); });
	
	
	
	
	## help menu
	my $help=$menubar->cascade(-label =>'~'.$VOCP::Strings::Strings{$Lang}{'help'}  || 'help', 
					-tearoff =>0,%menubutton_colors);
	$help->menu->configure( %menubutton_colors);
	$help->command(-label => "~$VOCP::Strings::Strings{$Lang}{'help'}...",%menubutton_colors,
			-command => \&help);
	$help->separator();
	
	$help->command(-label => $VOCP::Strings::Strings{$Lang}{'version'},%menubutton_colors);
	#$help->separator;
	$help->command(-label => $VOCP::Strings::Strings{$Lang}{'about'},%menubutton_colors);
	
	## bind dialogs to help menu entries
	my $menu = $help->cget('-menu');
	$menu->entryconfigure($VOCP::Strings::Strings{$Lang}{'version'}, -command => \&ShowVers ); #[$VERSIONBox => 'Show']);
	$menu->entryconfigure($VOCP::Strings::Strings{$Lang}{'about'}, -command => \&ShowAbout);

	return $menubar	 # return just built menubar

} # end build_menubar









sub build_viewer_menu {
	my $parentWidget = shift || return undef;
	
	

	my $menubar = $parentWidget->Menu(-type => 'menubar', -relief => 'flat', -activeborderwidth => 0, 
				-foreground => '#FF0000', -background => '#FF0000',
				-disabledforeground => '#FF0000', -activeforeground => '#FF0000',
				 -activebackground => '#FF0000',  %menubutton_colors
				#-background => '#00566F',
				#-activebackground => '#0A6179');
			);
	$parentWidget->configure(-menu=>$menubar );

	## file menu
	my $fax = $menubar->cascade(-label => ($VOCP::Strings::Strings{$Lang}{'fax'} || 'fax'), -tearoff =>0, %menubutton_colors);
	
	$fax->menu->configure( %menubutton_colors);
	$fax->command(-label => ($VOCP::Strings::Strings{$Lang}{'open'}  || 'open') . '...',  %menubutton_colors,
			-command => \&view);
			
	$fax->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'create'}  || 'create') . '...' ,  %menubutton_colors,
			-command => \&create);

	
	
	
	$fax->command(-label =>($VOCP::Strings::Strings{$Lang}{'export'} || 'export') ,  %menubutton_colors,
			-command => \&viewExport);
	
	$fax->separator();
	
	$fax->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'sendqueue'}  || 'sendqueue') . '...' ,  %menubutton_colors,
			-command => \&send);

	$fax->separator();
	
	$fax->command(-label => '~' . ($VOCP::Strings::Strings{$Lang}{'exit'}  || 'exit') ,  %menubutton_colors,
			-command => \&viewExit);
		
	
	#### View
			
	my $view=$menubar->cascade(-label =>'~' . ($VOCP::Strings::Strings{$Lang}{'view'}  || 'view'), 
				-tearoff =>0,%menubutton_colors);
	
	$view->menu->configure( %menubutton_colors);
	
	$view->command(-label => "~$VOCP::Strings::Strings{$Lang}{'zoom'} $VOCP::Strings::Strings{$Lang}{'in'} in",%menubutton_colors,
			-command => \&viewZoomIn);
	
	$view->command(-label => "~$VOCP::Strings::Strings{$Lang}{'zoom'} $VOCP::Strings::Strings{$Lang}{'out'} out",%menubutton_colors,
			-command => \&viewZoomOut);
	$view->separator();
	
	$view->command(-label => "~10%",%menubutton_colors,
			-command => sub { viewZoomTo(10); });
	$view->command(-label => "~20%",%menubutton_colors,
			-command => sub { viewZoomTo(20); });
	$view->command(-label => "~33%",%menubutton_colors,
			-command => sub { viewZoomTo(33); } );
	$view->command(-label => "~50%",%menubutton_colors,
			-command => sub { viewZoomTo(50); } );
	$view->command(-label => "~75%",%menubutton_colors,
			-command => sub { viewZoomTo(75); } );
	$view->command(-label => "~100%",%menubutton_colors,
			-command => sub { viewZoomTo(100); } );
	$view->command(-label => "~150%",%menubutton_colors,
			-command => sub { viewZoomTo(150); } );
	$view->command(-label => "~200%",%menubutton_colors,
			-command => sub { viewZoomTo(200); } );
	
	$view->separator();
	
	$view->command(-label => "~" . ( $VOCP::Strings::Strings{$Lang}{'viewXloadImage'} || 'viewXloadImage'),%menubutton_colors,
			-command => \&viewXloadImage);
	
	$view->command(-label => "~" . ( $VOCP::Strings::Strings{$Lang}{'viewXloadImagefull'} || 'viewXloadImagefull'),%menubutton_colors,
			-command => \&viewXloadImageFullScale);
	
	return $menubar	 # return just built menubar

} # end build_menubar


sub selectNewFileWindow {
	my $parentWidget = shift || $MW;
	my $directory = shift ||  $Self->{'currentdir'};
	my $selectDir = shift;
	
	return selectFileWindow($parentWidget, $directory, $selectDir, 0);
}

sub selectFileWindow {
	my $parentWidget = shift || $MW;
	my $directory = shift ||  $Self->{'currentdir'};
	my $selectDir = shift;
	my $checkExist = shift;
	
	$checkExist = 1 unless (defined $checkExist);
	
	my %options = ( '-directory'	=> $directory);
	$options{'-verify'} = ['-d'] if ($selectDir);
	
	my $FSref = $parentWidget->FileSelect(%options);

	$FSref->configure(%XVOCP::Colors::label_attribs);
	my @labels = $FSref->Subwidget();
	foreach my $lab (@labels)
	{
	
		$lab->configure(%XVOCP::Colors::label_attribs);
		my @subSubs = $lab->Subwidget();
		foreach my $sub (@subSubs)
		{
			$sub->configure(-background => $XVOCP::Colors::DefUIAttrib{'background'});
		}
		
		
	}

	
	my $flist = $FSref->Subwidget('file_list');
	$flist->configure(%XVOCP::Colors::listbox_attribs); 
	$flist->Subwidget('label')->configure(%XVOCP::Colors::label_attribs);
	$flist->Subwidget('listbox')->configure(%XVOCP::Colors::listbox_attribs);
	$flist->Subwidget('xscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$flist->Subwidget('yscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$flist->Subwidget('corner')->configure(%XVOCP::Colors::label_attribs);
      
	my $dirlist = $FSref->Subwidget('dir_list');
	$dirlist->configure(%XVOCP::Colors::listbox_attribs); 
	$dirlist->Subwidget('label')->configure(%XVOCP::Colors::label_attribs);
	$dirlist->Subwidget('listbox')->configure(%XVOCP::Colors::listbox_attribs);
	$dirlist->Subwidget('xscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$dirlist->Subwidget('yscrollbar')->configure(%XVOCP::Colors::scrollbar_attribs);
	$dirlist->Subwidget('corner')->configure(%XVOCP::Colors::label_attribs);
      

	#$FSref->Subwidget('frame')->configure(%XVOCP::Colors::listbox_attribs, -relief => 'flat');
	my $dialog = $FSref->Subwidget('dialog');
	$dialog->configure(%XVOCP::Colors::label_attribs);
	#$dialog->Subwidget('B_Accept')->configure(%XVOCP::Colors::label_attribs);
	

	my $selectedFile = $FSref->Show();
	
	return unless ($selectedFile);
	
	
	my $newDir = $selectedFile;
	
	$newDir =~ s|(.+/)[^/]+$|$1|;
	$Self->{'currentdir'}  = $newDir;
	
	
	if ($checkExist)
	{
		unless (-e $selectedFile)
		{
			errorBox($parentWidget, "Can't find $selectedFile", 'Not Found');
			return;
		}
	
		unless (-r $selectedFile)
		{
			errorBox($parentWidget, "Can't read $selectedFile", 'Not Found');
			return;
		}
	}
	
	
	
	return $selectedFile;
}

	






# The REAPER is needed to collect dead children, lest they turn to zombies
sub REAPER {
               my $waitedpid = wait;
               # loathe sysV: it makes us not only reinstate
               # the handler, but place it after the wait
	       print STDERR "The REAPER has got you, $waitedpid!" if ($main::Debug);
               $SIG{CHLD} = \&REAPER;
}
