package XVOCP;


use VOCP::Vars;



use strict;

use vars qw {
		%Images
		$VocpLocalDir
};

$VocpLocalDir = $VOCP::Vars::Defaults{'vocplocaldir'} || '/usr/local/vocp/';

%Images = (
		'popup'		=> "$VocpLocalDir/images/sys/message_small.jpg",
		'ok'		=> "$VocpLocalDir/images/sys/l_ok.jpg",
		'ok_over'	=> "$VocpLocalDir/images/sys/l_ok_over.jpg",
		'find'		=> "$VocpLocalDir/images/sys/l_find.jpg",
		'close'		=> "$VocpLocalDir/images/sys/l_close.jpg",
		'close_over'	=> "$VocpLocalDir/images/sys/l_close_over.jpg",
		'add'		=> "$VocpLocalDir/images/sys/l_add.jpg",
		'remove'	=> "$VocpLocalDir/images/sys/l_remove.jpg",
		'send'		=> "$VocpLocalDir/images/sys/l_send.jpg",
		'send_over'	=> "$VocpLocalDir/images/sys/l_send_over.jpg",
		'cancel'	=> "$VocpLocalDir/images/sys/l_cancel.jpg",
		'cancel_over'	=> "$VocpLocalDir/images/sys/l_cancel_over.jpg",
		'messagebg'	=> "$VocpLocalDir/images/sys/message_small.jpg",
		'confirmbg'	=> "$VocpLocalDir/images/sys/message_small.jpg",
		'forwardbg'	=> "$VocpLocalDir/images/xvocp/forward.jpg",
		'sendbg'	=> "$VocpLocalDir/images/sys/message_big02.jpg",
		'sendfaxbg'	=> "$VocpLocalDir/images/vocphax/sendfax.jpg",
		'ogg'		=> "$VocpLocalDir/images/xvocp/l_ogg.jpg",
		'mp3'		=> "$VocpLocalDir/images/xvocp/l_mp3.jpg",
		'wav'		=> "$VocpLocalDir/images/xvocp/l_wav.jpg",
		'errortitle'	=> "$VocpLocalDir/images/sys/message_error.jpg",
		'infotitle'	=> "$VocpLocalDir/images/sys/message_info.jpg",
		'warningtitle'	=> "$VocpLocalDir/images/sys/message_warning.jpg",
		'warningtitle'	=> "$VocpLocalDir/images/sys/message_confirm.jpg",
		'forwardtitle'	=> "$VocpLocalDir/images/xvocp/forward_title.jpg",
		'helptitle'	=> "$VocpLocalDir/images/sys/help_title.jpg",
		'helpbg'	=> "$VocpLocalDir/images/sys/message_big02.jpg",
		'aboutbg'	=> "$VocpLocalDir/images/sys/about.jpg",
		'versionbg'	=> "$VocpLocalDir/images/sys/message_small.jpg",
	);
	


package XVOCP::Colors;

use strict;

use vars qw {
		%menubutton_colors
		%button_colors
		%scrollbar_attribs
		%listbox_attribs
		%label_attribs
		%labentry_attribs
		%labentryLight_attribs
		%radiobutton_attribs
		%labelInv_attribs
		%textentry_attribs
		%DefUIAttrib
	};

%DefUIAttrib = (
		'background'	=> '#09557B',
		'activebackground' => '#166582',
		'highlbackground'	=> '#09557B',
		'foreground'	=> '#E1F5FE',
		'relief'	=> 'flat',
		'textlabelbg'	=> '#E1F5FE',
		'backgroundLight'	=> '#5ba6cd',
		);


%menubutton_colors = (
	'-activebackground' => '#10567C',
	'-activeforeground' => '#E1F5FF',
	'-background' => '#09557B',
	'-foreground' => '#E1F5FF',
	
	);

%button_colors = (
	'-highlightbackground' => '#055A74',
	'-highlightcolor'	=> '#EEEEFF',
	'-activebackground' => '#0A6179',
	'-activeforeground' => '#E1F5FF',
	'-background' => '#09557B',
	'-foreground' => '#E1F5FF',
	);


%scrollbar_attribs = (
	'-highlightbackground' => '#09557B',
	'-highlightcolor'	=> '#09557B',
	'-activebackground' => '#E1F5FF',
	#'-background' => '#D1E5EF',
	'-background' => '#E1F5FF',
	#'-troughcolor'	=> '#5ba6cd',
     	'-relief'	=> 'flat',
	'-borderwidth'	=> 1,
	'-troughcolor'	=> '#E1F5FF',
     	);

%listbox_attribs = (
	'-background' => '#E9F7FF',
	'-foreground' => '#000000',
	'-selectbackground' => '#E9F7FF',
	'-selectforeground' => '#FF0000',
	'-highlightbackground' => '#E9F7FF',
	'-highlightcolor' => '#E9F7FF',
);
%textentry_attribs = (
	'-background'	=> '#FFFFFF',
	'-foreground'	=> '#09557B',
	'-relief'	=> 'flat',
);
%label_attribs = (
	'-background' => '#09557B',
	'-foreground' => '#E1F5FF',
);

%labelInv_attribs = (
	'-background' => $label_attribs{'-foreground'},
	'-foreground' => $label_attribs{'-background'},
);
%labentry_attribs = ( 
			-labelBackground => $DefUIAttrib{'background'},
			-labelForeground => $DefUIAttrib{'foreground'},
			%listbox_attribs
	);

%labentryLight_attribs = ( 
			-labelBackground => $DefUIAttrib{'textlabelbg'},
			-labelForeground => $DefUIAttrib{'background'},
			%listbox_attribs
	);
	
%radiobutton_attribs = (
		'-highlightbackground' => '#E1F5FF',
		'-highlightcolor'	=> '#E1F5FF',
		'-activebackground' => '#E1F5FF',
		'-activeforeground' => '#09557B',
		'-background' => '#E1F5FF',
		'-foreground' => '#09557B',
		'-selectcolor' => '#09557B',
		);



package XVOCP::WindowGenerator;

use Tk 8.0;
use Tk::widgets ;
use Tk::Dialog;
use Tk::DialogBox;
use Tk::LabEntry;
use Tk::Image;
use Tk::Pixmap;
use Tk::JPEG;

use FileHandle;
use VOCP::Util;

use strict;

use vars qw {
		%Defaults
		%Types
		%Action
		
	};
	

%Defaults = (
		'geometry'	=> '460x348',
		'imagefmt'	=> 'jpeg',
	);

%Action = (
		'CONFIRM'	=> 1,
		'CANCEL'	=> 0,
		'CUSTOM'	=> 2,
	);

%Types = (	
		'message'	=> {
					'buttons'	=>  {
								'list'	=> [ 'ok' ],
								'specs'	=> {
											'ok'	=> {
													'x'	=> 145,
													'y'	=> 118,
													'action'	=> $Action{'CONFIRM'},
												},
											}
							},
					'title'		=> 'VOCP Message',
					
					'bgimage'	=> $XVOCP::Images{'messagebg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '313x150',
			},
			
		'confirm'	=> {
					'buttons'	=>  {
								'list'	=> [ 'ok', 'cancel' ],
								'specs'	=> {
											'ok'	=> {
													'x'	=> 93,
													'y'	=> 118,
													'action'	=> $Action{'CONFIRM'},
												},
											
											'cancel'	=> {
													'x'	=> 188,
													'y'	=> 117,
													'action'	=> $Action{'CANCEL'},
												},
									},
							},
					'title'		=> 'Confirm',
					'bgimage'	=> $XVOCP::Images{'confirmbg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '313x150',
			},
		
		
		'send'	=> {
					'buttons'	=>  {
								'list'	=> [ 'send', 'cancel' ],
								'specs'	=> {
											'send'	=> {
													'x'	=> 122,
													'y'	=> 303,
													'action'	=> $Action{'CONFIRM'},
												},
											
											'cancel'	=> {
													'x'	=> 277,
													'y'	=> 303,
													'action'	=> $Action{'CANCEL'},
												},
									},
							},
					'title'		=> 'Send',
					'bgimage'	=> $XVOCP::Images{'sendbg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '456x333',
			},
			
		
		'sendfax'	=> {
					'buttons'	=>  {
								'list'	=> [ 'send', 'cancel' ],
								'specs'	=> {
											'send'	=> {
													'x'	=> 87,
													'y'	=> 169,
													'action'	=> $Action{'CONFIRM'},
												},
											
											'cancel'	=> {
													'x'	=> 170,
													'y'	=> 169,
													'action'	=> $Action{'CANCEL'},
												},
									},
							},
					'title'		=> 'Send',
					'bgimage'	=> $XVOCP::Images{'sendfaxbg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '313x201',
			},
			
		
		
		
		'forward'	=> {
					'buttons'	=>  {
								'list'	=> [ 'send', 'cancel' ],
								'specs'	=> {
											'send'	=> {
													'x'	=> 122,
													'y'	=> 253,
													'action'	=> $Action{'CONFIRM'},
												},
											
											'cancel'	=> {
													'x'	=> 277,
													'y'	=> 253,
													'action'	=> $Action{'CANCEL'},
												},
									},
							},
					'title'		=> 'forward',
					'bgimage'	=> $XVOCP::Images{'forwardbg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '456x287',
			},
			
			
		'help'	=> {
					'buttons'	=>  {
								'list'	=> [ 'ok', 'find' ],
								'specs'	=> {
											'ok'	=> {
													'x'	=> 222,
													'y'	=> 300,
													'action'	=> $Action{'CONFIRM'},
												},
											'find'	=> {
													'x'	=> 260,
													'y'	=> 271,
													'action'	=> $Action{'CUSTOM'},
												},
									},
							},
					'title'		=> 'Help',
					'bgimage'	=> $XVOCP::Images{'helpbg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '456x333',
			},
		
		'about'	=> {
					'buttons'	=>  {
								'list'	=> [ 'close' ],
								'specs'	=> {
											'close'	=> {
													'x'	=> 136,
													'y'	=> 173,
													'action'	=> $Action{'CONFIRM'},
												},
											
									},
							},
					'title'		=> 'About',
					'bgimage'	=> $XVOCP::Images{'aboutbg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '313x201',
			},
			
		'version'	=> {
					'buttons'	=>  {
								'list'	=> [ 'ok' ],
								'specs'	=> {
											'ok'	=> {
													'x'	=> 145,
													'y'	=> 118,
													'action'	=> $Action{'CONFIRM'},
												},
											
									},
							},
					'title'		=> 'version',
					'bgimage'	=> $XVOCP::Images{'versionbg'},
					'bgimagefmt'	=> 'jpeg',
					'background'	=> $XVOCP::Colors::DefUIAttrib{'background'} || '#09557B',
					'geometry'	=> '313x150',
			},
		
);



sub new {
	my $class = shift;
	my %options = @_;
	
	my $self = {};
	bless $self, ref $class || $class;
	
	
	while (my ($key, $val) = each %options)
	{
		$self->{$key} = $val;
	}
	
	return $self;
	
}

sub show {
	my $self = shift;
	my $name = shift || $self->{'_lastname'};
	
	
	
	
	$self->{$name}->{'window'}->deiconify();
	
	$self->{$name}->{'window'}->update();
	
	if ($self->{$name}->{'modal'})
	{
		$self->{$name}->{'action'} = '' unless ($self->{$name}->{'action'});
		$self->{$name}->{'window'}->waitVariable(\$self->{$name}->{'action'});
	}
	
	
	

}

sub action {
	my $self = shift;
	my $setTo = shift;
	my $name = shift || $self->{'_lastname'};
	
	if (defined $setTo)
	{
		print STDERR "Setting XVOCP::WindowGenerator action to '$setTo'\n" if ($main::Debug);
		
		$self->{$name}->{'action'} = $setTo;
	}
	
	return $self->{$name}->{'action'};
}



sub changeImage {
	my $self = shift;
	my $winName = shift;
	my $name = shift;
	my $state = shift;
	
	my $labname = $name . '_label';
	my $onImgName = $name . '_over';
	
	return unless (defined $self->{$winName}->{'labels'}->{$labname} && 
				defined $self->{$winName}->{'images'}->{$onImgName});
				
	if ($state eq 'on')
	{
		$self->{$winName}->{'labels'}->{$labname}->configure(-image => $self->{$winName}->{'images'}->{$onImgName});
	} else {
		
		$self->{$winName}->{'labels'}->{$labname}->configure(-image => $self->{$winName}->{'images'}->{$name});
	}
	
}




sub newWindow {
	my $self = shift;
	my %params = @_;
	
	
	my $parent = $params{'parent'} || $self->{'parent'};
	
	unless ($self->{'parent'})
	{
		$self->{'parent'} = $parent;
	}
	
	my $name = $params{'name'} || $self->{'name'} || 'newwindow';
	my $type = $params{'type'} || $self->{'type'} || 'message';
	my $title;
	if ($type eq 'error')
	{
		$type = 'message';
		$title = 'Error';
	}
	$title =  $params{'title'} || $self->{'title'} || $Types{$type}{'title'} || 'XVOCP';
	
	my $background = $params{'background'} || $self->{'background'} || $Types{$type}{'background'};
	my $bgimage = $params{'bgimage'} || $self->{'bgimage'}  || $Types{$type}{'bgimage'};
	my $bgimagefmt = $params{'bgimagefmt'} || $self->{'bgimagefmt'} || $Types{$type}{'bgimagefmt'} || $Defaults{'imagefmt'};
	my $geometry = $params{'geometry'} || $self->{'geometry'} || $Types{$type}{'geometry'} ;
	my $dontDestroy = $params{'nodestroy'} || 0;
	
	my $modal = 0;
	
	$modal = 1 if ($params{'modal'} || $self->{'modal'});
	
	
	my $temp_win = $parent->Toplevel(	-title=> $title,
						-background => $background,);
	$temp_win->withdraw();
	
	$self->{$name}->{'window'} = $temp_win;
	$self->{$name}->{'geometry'} = $geometry if ($geometry);
	$self->{$name}->{'nodestroy'}= $dontDestroy;
	$self->{'_lastname'} = $name;
	$self->{$name}->{'modal'}++ if ($modal);
	
	if ($bgimage)
	{
		$self->{'bgimageobject'} = $parent->Photo($name . '_bgimage', -file => $bgimage, -format => $bgimagefmt);
		$self->{'bgimagelabel'} = $temp_win->Label(-image => $self->{'bgimageobject'}, -bg => $background)->place(
						-x => 0,
						-y => 0,
					);
	}
	
	my $buttonBG = $XVOCP::Colors::DefUIAttrib{'backgroundLight'};
	$self->{$name}->{'action'} = '';
	foreach my $buttonName (@{$Types{$type}{'buttons'}{'list'}})
	{
		
		my $label = 'B_'. $buttonName . '_image';
		my $overlabel = 'B_'. $buttonName . '_image_over';
		$self->{$name}->{'images'}->{$label} = $parent->Photo($label, -file => $XVOCP::Images{$buttonName}, -format => 'jpeg');
		my $mouseover = $XVOCP::Images{$buttonName . '_over'};
		if ($mouseover && -e $mouseover)
		{
			$self->{$name}->{'images'}->{$overlabel} = 
					$parent->Photo($overlabel, -file => $mouseover, -format => 'jpeg');
		}
			
		$self->{$name}->{'labels'}->{$label . '_label'} = 
					$temp_win->Label(-image => $self->{$name}->{'images'}->{$label}, 
								-bg => $buttonBG,
								-takefocus => 1)->place(
						-x => $Types{$type}{'buttons'}{'specs'}{$buttonName}{'x'},
						-y => $Types{$type}{'buttons'}{'specs'}{$buttonName}{'y'},
					);
		if ($Types{$type}{'buttons'}{'specs'}{$buttonName}{'action'} == $Action{'CONFIRM'})
		{
		
			$self->{$name}->{'labels'}->{$label . '_label'}->bind('<ButtonRelease-1>', 
							sub {
								$self->action($Action{'CONFIRM'}, $name);
								unless ($self->{$name}->{'nodestroy'})
								{
									print STDERR "Confirmed - destroying $name\n" if ($main::Debug);
									$self->{$name}->{'window'}->destroy();
									delete $self->{$name}->{'window'};
								}
							} );
		} elsif ($Types{$type}{'buttons'}{'specs'}{$buttonName}{'action'} == $Action{'CANCEL'}) 
		{
			$self->{$name}->{'labels'}->{$label . '_label'}->bind('<ButtonRelease-1>', 
							sub {
								$self->action($Action{'CANCEL'}, $name);
								unless ($self->{$name}->{'nodestroy'})
								{
									print STDERR "Cancelled - destroying $name\n" if ($main::Debug);
									$self->{$name}->{'window'}->destroy();
									delete $self->{$name}->{'window'};
								}
							} );
		}
		
		
	}
	
	foreach my $labelname (keys %{$self->{$name}->{'images'}})
	{
		
		next unless ($labelname =~ m|(.*)_over$|);
		my $labname = $1;
		next unless (defined $self->{$name}->{'labels'}->{$labname . '_label'});
		
		$self->{$name}->{'labels'}->{$labname . '_label'}->bind('<Enter>', sub { $self->changeImage($name, $labname , 'on');});	
		$self->{$name}->{'labels'}->{$labname . '_label'}->bind('<Leave>', sub { $self->changeImage($name, $labname, 'off');});
		$self->{$name}->{'labels'}->{$labname . '_label'}->bind('<FocusIn>', sub { $self->changeImage($name, $labname , 'on');});	
		$self->{$name}->{'labels'}->{$labname . '_label'}->bind('<FocusOut>', sub { $self->changeImage($name, $labname, 'off');});
	}
		
	$self->{$name}->{'window'}->geometry($self->{$name}->{'geometry'})
	 			if ($self->{$name}->{'geometry'});
	
	
	$temp_win->grab() if ($modal);
	
	return $temp_win;
	
}

sub helpWindow {
	my $self = shift;
	my %params = @_;
	
	
	my $text = '';
	if ($params{'text'})
	{
		$text = $params{'text'};
	} elsif ($params{'file'})
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() File $params{'file'} not found.")
				unless (-e $params{'file'});
	
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Can't read $params{'file'} .")
				unless (-r $params{'file'});
	
		my $helpfile = FileHandle->new();
		unless ($helpfile->open("<$params{'file'}"))
		{
			return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() problems opening $params{'file'} $!");
		}
		
		$text = join('', $helpfile->getlines());
		
		$helpfile->close();
	} else
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Must specify some text or a file.");
	}
	
	if ($params{'forceuntaint'} && $text)
	{
		if ($text =~ m|^(.+)$|sm)
		{
			$text = $1;
		}
	}
	my $winName = 'help';
	my $popup = $self->newWindow(			'type'	=> 'help',
							'name'	=> $winName,
							'modal'	=> $params{'modal'},
							'title'	=> $params{'title'} || "Help",
							
					);
	
	my $bg = $XVOCP::Colors::DefUIAttrib{'backgroundLight'} || '#09557B';
	
	my $titleImg = $popup->Photo($winName . '_title', -file => $XVOCP::Images{'helptitle'},-format => 'jpeg');
	$popup->Label(-image => $titleImg, -bg => $bg)->place(	-x => '183',
								-y => '14',
							);
	$self->{$winName}->{'labels'}->{'B_find_image_label'}->configure( %XVOCP::Colors::labelInv_attribs );
	#$XVOCP::Colors::DefUIAttrib{'backgroundLight'});
	my $maxChars = 59;
	my $scrolled = $popup->Scrolled('Text',	
			-font => 'fixed -10',
			-scrollbars => 'e',
			-relief => 'flat',
			-width => $maxChars,
			-height => '22',
			%XVOCP::Colors::listbox_attribs,
			%XVOCP::Colors::textentry_attribs,
			)->place(
						-x => 50,
						-y => 40,
					);
	$scrolled->Subwidget('yscrollbar')->configure(-relief => 'flat', -borderwidth =>1, -highlightthickness => 0, 
							%XVOCP::Colors::scrollbar_attribs);
	
	$self->{'help'}->{'_helpText'} = $scrolled;
	$self->{'help'}->{'_findEntry'} = '';
	my $searchField = $popup->Entry(
			%XVOCP::Colors::listbox_attribs,
			-relief => 'groove',
			-font => 'fixed -10',
			-width => 10,
			-textvariable => \$self->{'help'}->{'_findEntry'},
	)->place(
		-x => '180',
		-y => '270',
	);
	
	$searchField->bind('<Return>', sub { $self->_helpFind();});
	$self->{'help'}->{'labels'}->{'B_find_image_label'}->bind('<ButtonRelease-1>' , sub { $self->_helpFind();});
	
	# Get rid of annoying choppi
	#ng of words at end of line		
	my $minchars = $maxChars - 15;
	$text =~ s/(.{$minchars,$maxChars})\s/$1\n/g;
	
	$scrolled->insert('1.0', $text);
	$scrolled->markSet('insert', '1.0');
	$self->show($winName);
	
	return;
}

sub _helpFind {
	my $self = shift;
	
	my $searchLen = length($self->{'help'}->{'_findEntry'});
	return unless ($searchLen);
	
	my $insert = $self->{'help'}->{'_helpText'}->index('insert');
	my $end = $self->{'help'}->{'_helpText'}->index('end');
	if ($self->{'help'}->{'_helpText'}->compare($insert, '>=', $end))
	{
		$insert = '1.0';
	}

	
	my $res = $self->{'help'}->{'_helpText'}->search('-forwards', $self->{'help'}->{'_findEntry'} , $insert);
	my $olires = $res;
	
	if ($res && $res =~ m|^(\d+)\.(\d+)|)
	{
		my $line = $1;
		my $chars = $2;
		$chars+= $searchLen;
		$res = "$line.$chars";
	} else {
		return;
	}
	
	$self->{'help'}->{'_helpText'}->markSet('insert', $res);
	$self->{'help'}->{'_helpText'}->yview($res);
	$self->{'help'}->{'_helpText'}->tagRemove('sel', '1.0', 
							$self->{'help'}->{'_helpText'}->index('end'));
	$self->{'help'}->{'_helpText'}->markSet('sel', $res);
	$self->{'help'}->{'_helpText'}->tag("add","sel",$olires,$res);
}


sub errorWindow {
	my $self = shift;
	
	return $self->_msgWindow('errortitle', @_);
}

sub infoWindow {
	my $self = shift;
	
	return $self->_msgWindow('infotitle', @_);
}

sub warningWindow {
	my $self = shift;
	return $self->_msgWindow('warningtitle', @_);
}


sub _msgWindow {
	my $self = shift;
	my $titleImgName = shift;
	my %params = @_;
	
	
	my $text = '';
	my $image = '';
	my $parent = $params{'parent'} || $self->{'parent'};
	
	if ($params{'text'})
	{
		$text = $params{'text'};
	} elsif ($params{'file'})
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() File $params{'file'} not found.")
				unless (-e $params{'file'});
	
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Can't read $params{'file'} .")
				unless (-r $params{'file'});
	
		my $versionfile = FileHandle->new();
		unless ($versionfile->open("<$params{'file'}"))
		{
			return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() problems opening $params{'file'} $!");
		}
		
		$text = join('', $versionfile->getlines());
		
		$versionfile->close();
	} elsif ($params{'image'})
	{
		$image = $params{'image'};
	
	} else
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Must specify some text or a file.");
	}
	
	
	my $winName = 'error';
	my $popup = $self->newWindow(			'type'	=> 'message',
							'name'	=> $winName,
							'modal'	=> $params{'modal'},
							'title'	=> $params{'title'} || "Error",
							'parent'	=> $parent,
					);
	
	my $bg = $XVOCP::Colors::DefUIAttrib{'backgroundLight'} || '#09557B';
	
	my $titleImg = $popup->Photo($winName . '_title', -file => $XVOCP::Images{$titleImgName},-format => 'jpeg');
	$popup->Label(-image => $titleImg, -bg => $bg)->place(	-x => '123',
								-y => '11',
							);
	
	if ($params{'image'})
	{
		my $imgobj = $popup->Photo('error_customimage', -file => $params{'image'}, -format => 'jpeg');
		$popup->Label(-image => $imgobj)->place(	-x => '10',
								-y => '10',
							);
	}
	
	if ($text)
	{
		
		$text =~ s/(.{20,30}\s)/$1\n/g;
		$text =~ s/\n\s+/\n/g;
	
		$popup->Label(-text => $text,
				%XVOCP::Colors::labelInv_attribs)->place(
							-x => 60,
							-y => 50);
	
	}
	
	
	$self->show($winName);
	
	return;
}
		

sub versionWindow {
	my $self = shift;
	my %params = @_;
	
	
	my $text = '';
	my $image = '';
	if ($params{'text'})
	{
		$text = $params{'text'};
	} elsif ($params{'file'})
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() File $params{'file'} not found.")
				unless (-e $params{'file'});
	
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Can't read $params{'file'} .")
				unless (-r $params{'file'});
	
		my $versionfile = FileHandle->new();
		unless ($versionfile->open("<$params{'file'}"))
		{
			return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() problems opening $params{'file'} $!");
		}
		
		$text = join('', $versionfile->getlines());
		
		$versionfile->close();
	} elsif ($params{'image'})
	{
		$image = $params{'image'};
	
	} else
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Must specify some text or a file.");
	}
	
	
	my $winName = 'version';
	my $popup = $self->newWindow(			'type'	=> 'version',
							'name'	=> $winName,
							'modal'	=> $params{'modal'},
							'title'	=> $params{'title'} || "Version",
							
					);
	my $bg = $XVOCP::Colors::DefUIAttrib{'backgroundLight'} || '#09557B';
	
	if ($params{'image'})
	{
		my $imgobj = $self->{'parent'}->Photo('version_bgimage', -file => $params{'image'}, -format => 'jpeg');
		$popup->Label(-image => $imgobj)->place(	-x => '10',
								-y => '10',
							);
	}
	
	
	if ($text)
	{
		
		$text =~ s/(.{20,30}\s)/$1\n/g;
		$text =~ s/\n\s+/\n/g;
	
		$popup->Label(-text => $text,
				%XVOCP::Colors::labelInv_attribs)->place(
							-x => 60,
							-y => 50);
	
	}

	
	$self->show($winName);
	
	return;
}
					

sub aboutWindow {
	my $self = shift;
	my %params = @_;
	
	
	my $text = '';
	my $image = '';
	if ($params{'text'})
	{
		$text = $params{'text'};
	} elsif ($params{'file'})
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() File $params{'file'} not found.")
				unless (-e $params{'file'});
	
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Can't read $params{'file'} .")
				unless (-r $params{'file'});
	
		my $aboutfile = FileHandle->new();
		unless ($aboutfile->open("<$params{'file'}"))
		{
			return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() problems opening $params{'file'} $!");
		}
		
		$text = join('', $aboutfile->getlines());
		
		$aboutfile->close();
	} elsif ($params{'image'})
	{
		$image = $params{'image'};
	
	} else
	{
		return VOCP::Util::error("XVOCP::windowGenerator::helpWindow() Must specify some text or a file.");
	}
	
	
	my $winName = 'about';
	my $popup = $self->newWindow(			'type'	=> 'help',
							'name'	=> $winName,
							'modal'	=> $params{'modal'},
							'title'	=> $params{'title'} || "about",
							
					);
	
	if ($params{'image'})
	{
		my $imgobj = $self->{'parent'}->Photo('about_bgimage', -file => $params{'image'}, -format => 'jpeg');
		$popup->Label(-image => $imgobj)->place(	-x => '10',
								-y => '10',
							);
	}
	
	if ($text)
	{
		$popup->Label(-justify => 'center',
				-text => $text)->place(	-x => '20',
							-y => '20',
							);
	}
	
	
	$self->show($winName);
	
	return;
}
					
					
				

sub selectFile {
	my $self = shift;
	my $parentWidget = shift || $self->{'parent'};
	my $directory = shift ;
	my $selectDir = shift;
	
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
	
	return $selectedFile;
}

	


	
package XVOCP::DialogFactory;

use strict;

sub new {
	my $class = shift;
	my $options = shift;
	
	my $self = {};
	bless $self, ref $class || $class;
	
	return $self;
	
}

		      
sub confirmBox {
	my $self = shift;
	my $widget = shift;
	my $message = shift;
	my $title = shift || 'Confirmation';
	
	my $dia = $widget->Dialog(-title => $title,
				   -text  => '',
				   -buttons  => ['Ok', 'Cancel'],
				   #-bitmap => 'info', 
				   );
	
	$dia->geometry("460x348"); 
	
	unless ($self->{'_confirmBGImg'})
	{
		$self->{'_confirmBGImg'} = $dia->Photo('confbg', -file => $XVOCP::Images{'popup'}, -format => 'jpeg');
	}
	
	unless ($self->{'_okButtonImg'})
	{
		$self->{'_okButtonImg'} = $dia->Photo('okbut', -file => $XVOCP::Images{'ok'}, -format => 'jpeg');
	}
	
	unless ($self->{'_cancelButtonImg'})
	{
		$self->{'_cancelButtonImg'} = $dia->Photo('cancelbut', -file => $XVOCP::Images{'cancel'}, -format => 'jpeg');
	}
	
	
	my $bglabel = $dia->add('Label',  -bg => $XVOCP::Colors::DefUIAttrib{'background'}, 
					-image => $self->{'_confirmBGImg'})->place ( -x => 0, -y => 0);
	
	if ($message)
	{
		$dia->add('Label', -bg => $XVOCP::Colors::DefUIAttrib{'textlabelbg'}, -text => $message)->place( -x => 40, -y => 40);
	}
	$dia->Subwidget('B_Ok')->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -image => $self->{'_okButtonImg'} );
	$dia->Subwidget('B_Cancel')->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, -image => $self->{'_cancelButtonImg'} );
	
	my $resp = $dia->Show();
	return $resp;
	
}

sub errorBox {
	my $self = shift;
	my $widget = shift;
	my $message = shift;
	my $title = shift || 'Error';
	
	
	my $dia = $widget->Dialog(-title => $title,
					-buttons  => ['Ok'],
					#-bitmap => 'info'
					-bg => $XVOCP::Colors::DefUIAttrib{'background'},
					);
	$dia->geometry("460x348"); 
	
	unless ($self->{'_errorBGImg'})
	{
		$self->{'_errorBGImg'} = $dia->Photo('errorbg', -file => $XVOCP::Images{'popup'}, -format => 'jpeg');
	}
	
	unless ($self->{'_okButtonImg'})
	{
		$self->{'_okButtonImg'} = $dia->Photo('okbut', -file => $XVOCP::Images{'ok'}, -format => 'jpeg');
	}
	
	
	my $bglabel = $dia->add('Label')->place( -x => 0, -y => 0);
	$bglabel->configure(-bg => $XVOCP::Colors::DefUIAttrib{'background'}, 
					-image => $self->{'_errorBGImg'});
	
	#-bg => $XVOCP::Colors::DefUIAttrib{'background'}, 
	$dia->Subwidget('B_Ok')->configure(%XVOCP::Colors::button_colors, 
						-image => $self->{'_okButtonImg'} );
	
	if ($message)
	{
		$dia->add('Label', -bg => $XVOCP::Colors::DefUIAttrib{'textlabelbg'}, -text => $message)->place( -x => 40, -y => 40);
	}
	
	my $resp = $dia->Show();
	return $resp;

}






1;
