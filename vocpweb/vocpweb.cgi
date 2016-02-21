#!/usr/bin/perl -T
# Make sure you leave the taint checking (-T) on...

##################### vocpweb.cgi #######################
######                                            #######
######    Copyright (C) 2000-2003  Pat Deegan     #######
######            All rights reserved.            #######
#                                                       #
#   This program is free software; you can redistribute #
#   it and/or modify it under the terms of the GNU      #
#   General Public License as published by the Free     #
#   Software Foundation; either version 2 of the        #
#   License, or (at your option) any later version.     #
#                                                       #
#   This program is distributed in the hope that it will#
#   be useful, but WITHOUT ANY WARRANTY; without even   #
#   the implied warranty of MERCHANTABILITY or FITNESS  #
#   FOR A PARTICULAR PURPOSE.  See the GNU General      #
#   Public License for more details.                    #
#                                                       #
#   You should have received a copy of the GNU General  #
#   Public License along with this program; if not,     #
#   write to the Free Software Foundation, Inc., 675    #
#   Mass Ave, Cambridge, MA 02139, USA.                 #
#                                                       #
#   You may contact the author, Pat Deegan,             #
#   through the contact page on                         #
#   http://www.psychogenic.com
#                                                       #
#########################################################

use strict; # Make sure we do lots of error checking

# The location where VOCP is installed on this system
# (we need to use the VOCP.pm module)
my $VOCP_home = '/etc/vocp/';


my $DefaultCryptKey = 'randomstringREPLACEME904tnoietnor';


########## The encryption key to use  #############
### You MUST Replace "$DefaultCryptKey" with some random
### String...
###
### User data is encrypted using Crypt::CBC and a CipherAlgo
### then stored in a cookie.

#my $CryptKey = "$DefaultCryptKey";
my $CryptKey = "oaeu90aoneu90o,rao";


#### CipherAlgo #### 
#### Select and installed algorithm (perldoc Crypt::CBC
#### for details).  Valid entries are 'Blowfish'
#### Crypt::DES, Crypt::DES_EDE3, 
#### Crypt::IDEA, Crypt::Blowfish, and Crypt::Rijndael
####
#### The selected algo must be installed on the system
#### do "perl -MCPAN -e 'install Crypt::Blowfish'" if it isn't
my $CipherAlgo = 'Crypt::Blowfish';


# The location of the pvf tools (like pvftowav and rmdtopvf) - 
# These are installed with vgetty.
my $Pvftooldir = '/usr/local/bin';

# Run_suid says the program should be running suid if true.
# This is necessary when the VOCP setup is such that messages
# are set readonly for the owner.
# This cgi must run suid to be able to read users files.
# It starts as root, runs as nobody until it actually needs
# to suid to the user.  Then it goes back to nobody. 
# Check the website 
# http://VOCPsystem.com for details or read the source!
#
# If you do not wish to run suid, leave this at '0'.  You
# need, however, to make sure that the 'group' option is set
# (in the vocp.conf file) to the user your web server is 
# running as (usually 'nobody') or to the so that files will be readable
# by the server when running vocpweb.
my $Run_suid = 0;

# The name of the user the web server is running as (usually 'nobody')
# Only important when running set uid.
my $Web_serv_user = 'nobody';


# $Allow_deletes -- must set equal to '1' for users to be
# able to delete messages from the VOCPweb interface.  For the 
# deletions to work, the script must run suid (the $Run_suid variable
# above) - which involves many security considerations... 
# See the included documentation or the web site for details.
my $Allow_deletes = 0;

# Sets language for this cgi -- currently only english ('en') is supported
my $Lang = 'en';

#Default number of messages to jump with fast forward/back
my $Num_jump = 5;

# Default transfer and file format type
my $Default_transfer = 'download'; # 'download' or 'embed'
my $Default_format = 'wav'; 	# 'wav' or 'au'

# The full path to the cp (copy) program
my $Cp = '/bin/cp';

# Debug > 0 makes prog more verbose on stderr (error_log file)
use vars qw {
		$Debug
		$Thiscgi
		$Method
		$Safe
		%Templates
	};

$Debug = 0;

#################### END OF CONFIGURATION ####################
### You should not need to change anything below this line ###

use CGI; # Standard CGI module
use Crypt::CBC;
use VOCP;# The VOCP module
use VOCP::Util;

# Name of this cgi
$Thiscgi = 'vocpweb.cgi';

# Safe switch -> 1 = safe, 0 = unsafe
# Acts safer when true (won't execute stuff on the system as root...)
$Safe = 1;

# set to 'get' for debugging, else use 'post'
$Method = 'post';

# subdirs for templates and images
my $Tpldir = 'tpl';
my $Imgdir = 'img';
my $WebSounddir = 'sounds'; #This needs to be writeable by the process id (usually nobody) and
			 #is relative to the directory in which vocpweb.cgi is installed.

# Template files
%Templates = (
	'login'		=> "$Tpldir/login.html",
	'logout'	=> "$Tpldir/logout.html",
	'main'		=> "$Tpldir/main.html",
	'details'	=> "$Tpldir/details.html", 	# Details for a single message
	'list'		=> "$Tpldir/list.html",		# Details for all messages
	'list_element'	=> "$Tpldir/list_element.html",	# Tpl for one message in the list of all messages
	'badcookie'	=> "$Tpldir/badcookie.html", 
	);

# General image files
my %Img = (
	# Toggle switches and their mousover imgs
	'tog_form_wav'		=> "$Imgdir/b_wav.gif",
	'tog_form_wav_over'	=> "$Imgdir/b_wav_alt.gif",
	'tog_form_au'		=> "$Imgdir/b_au.gif",
	'tog_form_au_over'	=> "$Imgdir/b_au_alt.gif",
	'tog_xfer_dl'		=> "$Imgdir/b_disk.gif",
	'tog_xfer_dl_over' 	=> "$Imgdir/b_disk_alt.gif",
	'tog_xfer_em'		=> "$Imgdir/b_speaker.gif",
	'tog_xfer_em_over' 	=> "$Imgdir/b_speaker_alt.gif",
	
	#Current state images (in display)
	'cur_form_wav'	=> "$Imgdir/screen_wav.gif",
	'cur_form_au'	=> "$Imgdir/screen_au.gif",
	'cur_xfer_dl'	=> "$Imgdir/screen_disk.gif",
	'cur_xfer_em'	=> "$Imgdir/screen_speaker.gif",

	# Simple buttons -- no longer used in tpl
	'play'		=> "$Imgdir/c_play.gif",
	'forward' 	=> "$Imgdir/c_fw.gif",
	'ff' 		=> "$Imgdir/c_ffw.gif",
	'back' 		=> "$Imgdir/c_rew.gif",
	'fb' 		=> "$Imgdir/c_frew.gif",
	'del'	 	=> "$Imgdir/c_del.gif",
	'stop'	 	=> "$Imgdir/c_stop.gif",
	'details' 	=> "$Imgdir/b_info.gif",
	'list'		=> "$Imgdir/b_detail.gif",
	'logout' 	=> "$Imgdir/b_logout.gif",
);

# Image files corresponding to numbers
my %NUMimg = (
	'large' => {
		'off'	=> "$Imgdir/big0.gif",
		'0'	=> "$Imgdir/big0.gif",
		'1'	=> "$Imgdir/big1.gif",
		'2'	=> "$Imgdir/big2.gif",
		'3'	=> "$Imgdir/big3.gif",
		'4'	=> "$Imgdir/big4.gif",
		'5'	=> "$Imgdir/big5.gif",
		'6'	=> "$Imgdir/big6.gif",
		'7'	=> "$Imgdir/big7.gif",
		'8'	=> "$Imgdir/big8.gif",
		'9'	=> "$Imgdir/big9.gif",
		},
	'small' => {
		'off'	=> "$Imgdir/little0.gif",
		'0'	=> "$Imgdir/little0.gif",
		'1'	=> "$Imgdir/little1.gif",
		'2'	=> "$Imgdir/little2.gif",
		'3'	=> "$Imgdir/little3.gif",
		'4'	=> "$Imgdir/little4.gif",
		'5'	=> "$Imgdir/little5.gif",
		'6'	=> "$Imgdir/little6.gif",
		'7'	=> "$Imgdir/little7.gif",
		'8'	=> "$Imgdir/little8.gif",
		'9'	=> "$Imgdir/little9.gif",
		},
	);

# Strings contains all the language dependant strings that could not
# be left in the templates.  Currently only english is supported
# but this is easily changed by adding appropriate values in this hash
# and setting Lang to the right code (please stick to iso - ie. 'en', 'fr' etc).
my %Strings = (
	'en' => {
			'forward'	=> 'forward',
			'fastforward'	=> 'fastforward',
			'back'		=> 'back',
			'fastback'	=> 'fastback',
			'del'		=> 'delete',
			'play'		=> 'play',
			'stop'		=> 'stop',
			'details'	=> 'See details for this message',
			'list'		=> 'List details for all messages',
			'format'	=> 'toggle format',
			'transfer'	=> 'toggle transfer',
			'logout'	=> 'logout',
		},
);


# The contents of the Toggle hash determine which
# value is "next" when toggling a toggle button
# Of limited use in this case, will become quite usefull
# if we ever add more than 2 possible states: we'll only
# need to add a value here - no changes will be necessary
# to the toggling code.
my %Toggle = (
	'transfer' => {
		'download' => 'embed',
		'embed' => 'download',
		},
	
	'format' => {
		'wav' => 'au',
		'au' => 'wav',
		},
	);
	
	

# Name of the cookie to set in users browser
my $Cookiename = 'vocplogin';

# ORed string of valid sound formats
# (Seperate with '|' char)
my $Valid_formats = 'wav|au';

# Global VOCP object
my $Vocp;
my $Cachedir;

# Some security issues:
$ENV{ENV} = '';
$ENV{PATH} = '/bin:/usr/bin';
$ENV{CDPATH} = '';


#main
{
	my $self = {};
	bless $self;

	#Check if we were started as root and suid nobody
	if ($Run_suid) {
		$self->error("Permissions of $0 must be 4755 owned by root. Cannot run as $>")
			unless ($> == 0);
		
		$self->swap_uid($Web_serv_user);
	}
		
	# Create the query object
	# If you wish to run as a fastcgi, you must comment the next line
	# and uncomment the while{} loop (here and below)
	my $query = new CGI;
	# while (my $query = new CGI) {
	
	#Get the step we're at
	my $sub = $query->param('step');
	
	#Default step
	$sub ||= "login";
	
	#Check that step is valid (and NOT private)
	unless ($self->can($sub) && $sub !~ /^_/) {
	
		$self->error("Unknown step: $sub");
	}
	
	
	if ($CryptKey eq $DefaultCryptKey)
	{
		$self->error("You NEED to change the value of \$CryptKey to some random string.");
	}
	
	# Initialize the global VOCP object
		
	# We setup the options for our call to VOCP's new()
	#die_on_error does just that. We will need to eval each 
	#important call, but this allows us to show the user a 
	#meaningful message
	my $options = {
		'genconfig'	=> "$VOCP_home/vocp.conf",
		'voice_device_type'	=> 'none',
		'nocalllog'	=> 1, # no need for logging here...
		'usepwcheck'	=> 1, # run simply as user - need setgid pwcheck
		'die_on_error' => '1', 
	};
	
	# Call new in eval
	eval {
		$Vocp = VOCP->new($options)
			|| $self->error("Unable to create new VOCP object");
	};
	#Show an error msg if we had one
	$self->error($@) if ($@);	
	
	# Set cachedir and pvftools dir
	my $cache = $Vocp->{'cachedir'};
	
	$self->error("You need to set the cache option in vocp.conf to use vocpweb. Please do so.")
		unless ($cache);

	$Cachedir = VOCP::Util::full_path($cache, $Vocp->{'inboxdir'});
	
	$Pvftooldir = $Vocp->{'pvftooldir'}
		if ($Vocp->{'pvftooldir'});
		
	#Check that we're logged in
	if ($sub ne 'login') {
	
		# Send to login if not logged in
		unless ($self->_check_login($query)) {

			$self->_display_tpl($self->login($query));

			exit(0);
		}
		
	}
	
	# Execute the sub and collect its output
	my $output = $self->$sub($query);
	
	# Display it -> returning a '1' indicates
	# that the sub has taken care of it.
	$self->_display_tpl($output)
		unless ($output eq '1');
	
	# Uncomment next line if running as FASTCGI
	# } 
	# quit
	exit(0);
	
}
sub login { 
	my $self = shift;
	my $query = shift;
	
	if ($query->param()) { #This is the second call, trying to login
	
		if ($self->_check_login($query)) { #Valid login
			return $self->main($query);
		} else {
			$self->error(qq|Invalid login, <a href="$Thiscgi">try again</A>|);
		}
		
	}
	
	
	#Not yet logged in	
	my $values = {
		'startform' => $query->start_form(-method=>$Method),
		
		'box'	=> $query->textfield(-name=>'box',
					-size	=> 10,
					-maxlength =>30),
					
		'passwd'=> $query->password_field(-name => 'passwd',
                         		-size => 10,
					-maxlength => 30),
					
		'submit' => $query->submit('submit', 'Submit'),
		
		'endform' => $query->endform(), 
		
		};

	return $self->_fill_tpl($values, $Templates{'login'});
	
}



sub main {
	my $self = shift;
	my $query = shift;
	
	
	return $self->login()
			unless ($self->_check_login($query));

	my $box = $query->param('box');
	
	if ($box =~ /^([\w\d]+)$/) {
		$box = $1;
	} else {
		$self->error("Strange box number: $box");
	}
	
	return $self->login($query)
		unless (defined $box && $box eq $Vocp->valid_box($box));

	# Get list of messages for box
	my $messages = $Vocp->list_messages($box);
	my $num_msg = scalar @{$messages};
	
	# Get and validate the current message
	my $cur = $query->param('current') ;
	$cur = 1 if ( $num_msg && $cur && 
			( $cur > $num_msg || $cur < 1) );
	my $current_msg = $cur || ($num_msg ? '1' : '0');
	
	
	# Get the action, if user has submited the form
	my $action = $query->param('do');
	my ($attachment, $contenttype, $filename);
	if ($action && $num_msg) {
	
		my $sub = "_do_$action";
		$self->error("Unknown action: $action")
			unless ($self->can($sub));
		
		log_msg("Main() calling sub $sub")
			if $Debug;
		
		# The sub may return attachement to play
		($attachment, $contenttype, $filename)
			= $self->$sub($query, $messages, \$current_msg);
			
		if ($action eq 'del') { #We deleted a msg
			# Get list of messages for box
			$messages = $Vocp->list_messages($box);
			
			# Back up by 1 to let user know he/she's done something
			$self->_do_back($query, $messages, \$current_msg);
		}
		
	}
	log_msg("Current message is $current_msg")
		if $Debug;
	
	# Usefull values
	my $transfer = $query->param('transfer') || $Default_transfer;
	my $format = $query->param('format') || $Default_format;
	
	# Dynamic images that change depending on state
	#Numbers for messages
	my $total_img = $self->_number_to_img('small', $num_msg);
	my $current_img = $self->_number_to_img('large', $current_msg);
	
	#Transfer and format, which are toggled by user
	my ($toggle_transfer_img, $toggle_transfer_img_over, $current_transfer_img, 
		$toggle_format_img, $toggle_format_img_over, $current_format_img);
	
	# Transfer type, download or embeded in page
	if ($transfer eq 'download') { 
		$toggle_transfer_img = $Img{'tog_xfer_em'};
		$toggle_transfer_img_over = $Img{'tog_xfer_em_over'};
		$current_transfer_img = $Img{'cur_xfer_dl'};
		
	} else { 
		$toggle_transfer_img = $Img{'tog_xfer_dl'};
		$toggle_transfer_img_over = $Img{'tog_xfer_dl_over'};
		$current_transfer_img = $Img{'cur_xfer_em'};
	}
	
	# Format type, wav or au are supported for now
	if ($format eq 'wav') { 
		$toggle_format_img = $Img{'tog_form_au'};
		$toggle_format_img_over = $Img{'tog_form_au_over'};
		$current_format_img = $Img{'cur_form_wav'};
		
	} else {
		$toggle_format_img = $Img{'tog_form_wav'};
		$toggle_format_img_over = $Img{'tog_form_wav_over'};
		$current_format_img = $Img{'cur_form_au'};
	}

	my $std_param = "box=$box&current=$current_msg&transfer=$transfer&format=$format";

	log_msg("Using standard params in get:\n$std_param\n")
		if ($Debug > 1);
	
	my $values = {

		# Total num msg
		'total' => $total_img,
		# Num of current msg
		'current' => $current_img,
		
		
		# Forward 1 button
		'forward_img' 	=> $Img{'forward'},
		'forward_alt'	=> $Strings{$Lang}{'forward'},  
		'forward_href' 	=> "$Thiscgi?$std_param&do=forward",		

				
		# Fast forward button	
		'ff_img'	=> $Img{'ff'},
		'ff_alt'	=> $Strings{$Lang}{'fastforward'},
		'ff_href'	=> "$Thiscgi?$std_param&do=ff",
		
		# Backward 1 button
		'back_img'	=> $Img{'back'},
		'back_alt'	=> $Strings{$Lang}{'back'},
		'back_href'	=> "$Thiscgi?$std_param&do=back",
			
		# Fast backward button
                'fb_img'      => $Img{'fb'},
		'fb_alt'      => $Strings{$Lang}{'fastback'},
                'fb_href'     => "$Thiscgi?$std_param&do=fb", 

		# Delete button
                'del_img'      => $Img{'del'},
		'del_alt'      => $Strings{$Lang}{'del'},
                'del_href'     => "$Thiscgi?$std_param&do=del",

		# 'Play' button
                'play_img'      => $Img{'play'},
		'play_alt'	=> $Strings{$Lang}{'play'},
                'play_href'     => "$Thiscgi?$std_param&do=play",                                                                              

		# Stop button		
                'stop_img'      => $Img{'stop'},
		'stop_alt'	=> $Strings{$Lang}{'stop'},
                'stop_href'     => "$Thiscgi?$std_param",                                                                              

		
		# 'Details' button.
                'details_img'      => $Img{'details'},
		'details_alt'	=> $Strings{$Lang}{'details'},
                'details_href'     => "$Thiscgi?$std_param&step=details",                                                                              

		# List details of all messages button
                'list_img'      => $Img{'list'},
		'list_alt'	=> $Strings{$Lang}{'list'},
                'list_href'     => "$Thiscgi?$std_param&step=list",    
		                                                                          

		# Wav/au format button clicking toggles - Img changes depending on current
                'format_img'      => $toggle_format_img,
		'format_img_over' => $toggle_format_img_over,  
		'format_alt'      => $Strings{$Lang}{'format'},
                'format_href'     => "$Thiscgi?$std_param&do=format", 
		
		                                                                           	
		# Current format (wav or au) display image
		'current_format_img' => $current_format_img,		

		# download/embed transfer button clicking toggles - Img changes depending on current
                'transfer_img'      => $toggle_transfer_img,
		'transfer_img_over' => $toggle_transfer_img_over,
                'transfer_alt'      => $Strings{$Lang}{'transfer'},
                'transfer_href'     => "$Thiscgi?$std_param&do=transfer", 
		
	
		# Current transfer type (download or embeded) display image
		'current_transfer_img' =>  $current_transfer_img,

		# Logout button
                'logout_img'      => $Img{'logout'},
                'logout_alt'      => $Strings{$Lang}{'logout'},
                'logout_href'     => "$Thiscgi?$std_param&step=logout", 
		
		};
		
	my $page = $self->_fill_tpl($values, $Templates{'main'});
	
	if (($attachment && $attachment ne '1') || $contenttype) { #We've got extra work to do
	
		#We display the page ourselves, to include
		#the attachment
		$self->_display_tpl($page, $attachment, $contenttype, $filename);
		
		#Return 1 to indicate we've displayed the page
		return 1;
	}
	
	#Else we just return the page and let the caller display it
	return $page;
	
}


sub logout {
	my $self = shift;
	my $query = shift;
	
	my $box = $query->param('box');
	
	$self->error("Strange box number: $box")
		unless ($box =~ /^(\d+)$/);
		
	$box = $1;
	
	# Delete any sound files stashed in the websounddir for embeding
	# in web pages -- these files are readable by the web server, so we 
	# need to get rid of them.
	
	# Get the files cached for this box
#	opendir(WEBSOUNDS, "$WebSounddir")
#		|| $self->error("Could not open $WebSounddir to flush cached sound files: $!");
	
	my @cache_files;
#	while (my $file = readdir(WEBSOUNDS)) {
#		
#		if ($file =~ /^msg-$box/){
#			push @cache_files, $file;
#			log_msg("Found cached file $file")
#				if ($Debug > 1);
#		}
#	}
#
#	closedir (WEBSOUNDS)
#		|| warn "Had a hard time closing $WebSounddir: $!";
#	
	
	#Delete them.
	if (scalar @cache_files) { #we have files to delete
	
		# Swap uid to user, we want to be able to delete his (and only his)
		# files.  Box can't be owned by rewt.
		if ($Run_suid) {
	
			my $owner = $Vocp->owner();
	
			$self->error("Can't find owner of this box - can't swap uid.")
				unless (defined $owner);
		
			$self->swap_uid($owner);
		
			$self->error("Can't delete cached messages for this box: it is owned by "
				. "uid 0 (root) and Safe switch is on... change the owner of this box.")
				if ($Safe && ($owner eq 'root' || $> == 0) );
		
		}
	
		foreach my $file (@cache_files) {
		
			unless ($file =~ /^(msg-$box-\d+\.\w{2,3})$/) {
				log_msg("Trying to delete strange file name $file, skipping");
				next;
			}
			
			$file = $1;
			log_msg("Deleting file $WebSounddir/$file during logout")
				if ($Debug);
				
			my $deleted = unlink "$WebSounddir/$file";
			
			log_msg("Could not delete file $file...")
				unless $deleted;
			
		} # END foreach file
		
		# Swap back to nobody
		$self->swap_uid($Web_serv_user) if ($Run_suid) ;
		
	} #END if cached files

	# Optimisation for _check_login()
	delete $self->{'cookie_val'};
	
	# Used to set cookie in _display_tpl()
	# We set it to ''
	$self->{'cookie'} = $query->cookie(-name=>$Cookiename,
					   -value=> '',
					   );
	
	my $values = {
			'cgi' => $Thiscgi,
			};
	

	return $self->_fill_tpl($values, $Templates{'logout'});
	

	return 1;
	
}


sub _do_forward {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	my $amount = shift || '1';
	
	my $nummsg = scalar @{$messages};
	
	return undef
		unless ($nummsg);
	
	my $next = $$current_msg_ref + $amount;
	
	# Loop if we past the last message
	$next -= $nummsg
		if ($next > $nummsg);
	
	$$current_msg_ref = $next;
	
	$query->param('current', $$current_msg_ref);
	
	log_msg("Current message now set to $$current_msg_ref")
		if $Debug;
	
	return 1;
}

sub _do_ff {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	
	my $amount = $query->param('fnum') || $Num_jump;
	$amount = $Num_jump unless ($amount =~ /^\d{1,5}/);
	
	return $self->_do_forward($query, $messages, $current_msg_ref, $Num_jump);
	
}

sub _do_back {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	my $amount = shift || '1';
	
	my $nummsg = scalar @{$messages};
	
	return undef
		unless ($nummsg);
		
	my $next = $$current_msg_ref - $amount;
	
	#Loop if below 1
	$next = $nummsg + $next
		if ($next < 1 );
	
	$$current_msg_ref = $next;
	
	$query->param('current', $$current_msg_ref);
	
	
	log_msg("Current message now set to $$current_msg_ref")
		if $Debug;
	
	return 1;
}

sub _do_fb {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	
	my $amount = $query->param('fnum') || $Num_jump;
	$amount = $Num_jump unless ($amount =~ /^\d{1,5}/ );
	
	return $self->_do_back($query, $messages, $current_msg_ref, $Num_jump);
	
}

sub _do_play {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	
	my $index = $$current_msg_ref - 1;
	
	my $msg = $messages->[$index];
	
	# Get an untainted filename, without full path or extension plus extension
	my ($file, $ext) = VOCP::Util::clean_filename($msg);
	
	# Get a clean full
	my $filename = VOCP::Util::full_path("$file.$ext", $Vocp->{'inboxdir'}, 'SAFE');
	
	my $cantfind = 'Can\'t find an executable for conversion:';
	
	# Swap uid to user
	if ($Run_suid) {
	
		my $owner = $Vocp->owner();
	
		$self->error("Can't find owner of this box - can't swap uid.")
			unless (defined $owner);
		
		$self->swap_uid($owner);
		
		$self->error("Can't play messages for this box: it is owned by "
				. "uid 0 (root) and Safe switch is on... change the owner of this box.")
			if ($Safe && ($owner eq 'root' || $> == 0) );
		
	}
	
	# Set the umask restrictive to avoid race conditions
	my $oldmask = umask oct('0027');
	
	#Convert to pvf
	my $pvffile = "$Cachedir/$file.pvf";
	my ($ret, $error);
	($ret, $error) = $Vocp->rmd2pvf($filename, $pvffile);

	$self->error($error)
		if ($ret);
	
	chmod oct('0600'), $pvffile;
	
	my $formattype = $query->param('format') || 'wav';
	unless ( $formattype =~ /^($Valid_formats)$/ ) {
		#Invalid sound format, possible sploit
		$self->error("Invalid sound format: $formattype. Aborting");
	}
	# Passed taint check
	$formattype = $1;
	
	my $soundfile = "$Cachedir/$file.$formattype";
	($ret, $error) = $Vocp->pvf2X($pvffile, $soundfile, $formattype);
		
	$self->error($error)
		if ($ret);
	
	chmod oct('0600'), $soundfile;

	my $box = $query->param('box') ;
	unless ($box =~ /^(\d+)$/) {
		$self->error("Expecting box to be numeric... got $box instead!");
	}
	$box = $1;

	my $current = $query->param('current') ;
	unless ($current =~ /^(\d+)$/) {
		$self->error("Expecting current message to be numeric... go $current instead!");
	}
	$current = $1;

	my $download_name = "msg-$box-$current.$formattype";

	my $contenttype;
	if ($query->param('transfer') eq 'embed'){ #Embeded in html doc (use pluggin)
		$contenttype = 'embed';
		system("$Cp $soundfile $WebSounddir/$download_name");

		chmod oct('0644'), "$WebSounddir/$download_name";	
		
		$file = '';
		
	} else { # Download the file (use local prog)
		
		$file = $self->_get_file($soundfile);

	}

	# Swap back to nobody
	$self->swap_uid($Web_serv_user) if ($Run_suid) ;
	
	umask $oldmask;
	
	return ($file, $contenttype, $download_name);	
}

sub _do_del {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	
	
	$self->error("Sorry! System configured to disallow deletes from VOCPweb (for security). "
			. "Use the phone to do so.")
		unless ($Allow_deletes);

	
	my $index = $$current_msg_ref - 1;
	
	my $msg = $messages->[$index];
	
	$self->error("Invalid message number ")
		unless ($msg);

	# Swap uid to user
	if ($Run_suid) {
	
		my $owner = $Vocp->owner();
	
		$self->error("Can't find owner of this box - can't swap uid.")
			unless (defined $owner);
		
		$self->swap_uid($owner);
		
		$self->error("Can't delete messages for this box: it is owned by "
				. "uid 0 (root) and Safe switch is on... change the owner of the box.")
			if ($Safe && ($owner eq 'root' || $> == 0) );
	}
	
	
	$self->error("Sorry! Will not delete files for a box owned by root or invalid user!")
		if ($> == 0);
	
	my $ret = $Vocp->delete_msg_files($msg);
	
	$self->error("We seem to have had a problem deleting $msg")
		unless ($ret);
	
	# Swap back to nobody
	$self->swap_uid($Web_serv_user) if ($Run_suid) ;
	
	
	
	
	return 1;
}

# Not really used, does nothing, included for future 
sub _do_transfer {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	
	# Current type
	my $type = $query->param('transfer');
	
	# Next type
	my $newtype = $Toggle{'transfer'}{$type};
	
	$self->error("Unrecognized current transfer type $type")
		unless (defined $newtype);
	
	# Set new type
	$query->param('transfer', $newtype);
	
	
	return 1;
}

# Not really used, does nothing, included for future 
sub _do_format {
	my $self = shift;
	my $query= shift;
	my $messages = shift; 
	my $current_msg_ref = shift;
	
	# Current type
	my $type = $query->param('format');
	
	# Next type
	my $newtype = $Toggle{'format'}{$type};
	
	$self->error("Unrecognized current transfer type $type")
		unless (defined $newtype);
	
	# Set new type
	$query->param('format', $newtype);
	
	
	return 1;
}

# Shows details for current message.  
# Possible replacement values for templates:
#	perm (permissions)
#	ln (num links to file)
#	owner
#	group
#	date
#	size
#	file

sub details {
	my $self = shift;
	my $query= shift;

	my $msgnum = $query->param('current');
	my $boxnum = $query->param('box');
	
	$self->error("Invalid box format: $boxnum")
		unless ($boxnum =~ /^(\d+)$/);
	
	$boxnum = $1;
	
	$self->error("Current message number is invalid: $msgnum")
		unless ($msgnum =~ /^(\d+)$/);
	
	$msgnum = $1;
	
	
	my $detailed_msgs = $Vocp->list_messages($boxnum, 'LONG');
	
	$self->error("Invalid message number:$msgnum" )
		unless (defined $detailed_msgs->[$msgnum - 1]);
		
	my $details = $detailed_msgs->[$msgnum - 1];
	
	#form:
	#"$mode||$nlink||$uid||$gid||$size||$mtime||$afilename"
	my @details = split('\|\|', $details);
	
	# Set up values to be used within the template
	my $owner = (getpwuid($details[2]))[0];
	my $group = (getgrgid($details[3]))[0];
	
	#my ($name,$passwd,$uid,$gid,
         #             $quota,$comment,$gcos,$dir,$shell,$expire) = getpw
	
	
	my $datetime = $self->_getDateString($details[5]);
	my $values = {
			'perm' 	=> $details[0],
			'ln'	=> $details[1],
			'owner'	=> $owner,
			'group'	=> $group,
			'size'	=> $details[4],
			'date'	=> $datetime,
			'file'	=> $details[6],
		};

	return $self->_fill_tpl($values, $Templates{'details'});	

}

sub _getDateString {
	my $self = shift;
	my $date = shift || return;
	
	my ($sec,$min,$hour,$mday,
			$mon,$year,$wday,$yday,$isdst) = localtime($date);
	
	$mon += 1;
	$mon = "0$mon" if (length($mon) < 2);
	$mday = "0$mday" if (length($mday) < 2);
	
	$year += 1900 if ($year < 1900);
	$hour = "0$hour" if (length($hour) < 2);
	$min = "0$min" if (length($min) < 2);
	$sec = "0$sec" if (length($sec) < 2);
	
	return  "$year-$mon-$mday $hour:$min:$sec";
}

# Shows details for all messages with a link to jump to any given message
# This sub uses 2 templates: 
#	one for each of the list elements
#	one for the entire list (this is the page returned to the browser)
#
# Possible replacement values for templates:
#	list_element tpl:
#		num (msg number)
#		perm
#		ln (num links to file)
#		owner
#		group
#		date
#		size
#		file
#		url (url to jump to this message)
#		
#	whole list tpl
#		list (entire list)
#		box (this box number)
#		year (current year)
#		mon (current month)
#		mday (current day of month)
#		hour (current) 
#		min  (current) 
#		sec  (current) 
#		
#
sub list {
	my $self = shift;
	my $query= shift;

	my $current = $query->param('current');
	my $boxnum = $query->param('box');
	
	$self->error("Invalid box format: $boxnum")
		unless ($boxnum =~ /^(\d+)$/);
	
	$boxnum = $1;
	
	$self->error("Current message number is invalid: $current")
		unless ($current =~ /^(\d+)$/);
	
	$current = $1;


	my $detailed_msgs = $Vocp->list_messages($boxnum, 'LONG');
	
	# Retrieve the sub template used for a single list element
	my $subtpl = $self->_get_file($Templates{'list_element'});
	
	# Fill the sub template for each message and append to the list
	my ($url_current, $list);
	foreach my $message (@{$detailed_msgs}) {
	
		$url_current++;
		#"$mode||$nlink||$uid||$gid||$size||$mtime||$afilename"
		my @details = split('\|\|', $message);
	
		# Set up values to be used within the template
		my $owner = (getpwuid($details[2]))[0];
		my $group = (getgrgid($details[3]))[0];
	
		my $datetime = $self->_getDateString($details[5]);
		my $values = {
			'num'	=> $url_current,
			'perm' 	=> $details[0],
			'ln'	=> $details[1],
			'owner'	=> $owner,
			'group'	=> $group,
			'size'	=> $details[4],
			'date'	=> $datetime,
			'file'	=> $details[6],
			'url' 	=> qq|<A HREF="$Thiscgi?box=$boxnum&current=$url_current&format=|
				  . $query->param('format') . "&transfer=" . $query->param('transfer')
				  .qq|">Go</A>|,
		};
		
		

		$list .= $self->_fill_tpl($values, $subtpl);
	}
	
	# We now set the values for our template
	
	# Values for the tpl
	my $values = {
			'list' 	=> $list,
			'box'	=> $boxnum,
			'datetime'	=> $self->_getDateString(time()),
			
		};
		
	# We now fill the actual template with our list and return the page
	return $self->_fill_tpl($values, $Templates{'list'});		

}






sub _check_login {
	my $self = shift;
	my $query = shift;
	
	# Always have a box in the form
	my $box = $query->param('box');
	if ($box =~ /^(\d+)$/) {
		$box = $1;
	} else {
		$self->error("Strange box number: $box");
	}
	
	# May have a password
	my $passwd = $query->param('passwd');
	# May have a cookie
	my $cookie_val = $self->{'cookie_val'} || $query->cookie(-name=>$Cookiename);
	
	
	$self->error("Trying to check login but no VOCP object?")
		unless ($Vocp);
	
	# Validate the box number
	if (! defined $box) {
		$self->error("Must enter a box number.");
	} elsif ( ($box ne $Vocp->valid_box($box)) 
			|| (! $Vocp->is_mailbox($box)) ) { #Check that it's a valid box
	
		#We aren't too specific about the error so as to 
		#not give away our boxnumbers
		$self->error("Invalid login.");
	}
	
	
	# Validate the password, either through a cookie or the login
	# password box
	if ($cookie_val) { #Already logged in, have a cookie
	
		my $cipher = new Crypt::CBC( {
					'key'             => $CryptKey,
					'cipher'          => $CipherAlgo,
			});
	
		my $decrypted = $cipher->decrypt_hex($cookie_val);
	
		unless ($decrypted)
		{
			return $self->error("Could not decrypt the contents of your cookie.");
		}
		
		my ($password, $cookiebox, $salt, $hour, $mday, $salt2, $mon) = split('\|', $decrypted);
		
		unless ($password  && $cookiebox =~ m|^\d+$| && $cookiebox == $box)
		{
			return $self->error("Invalid content found in cookie.");
		}
		
		#Check that it is a real and valid cookie
		if ( $Vocp->check_password($box, $password) ) {
			
			# Stash the cookie, if it isn't already
			$self->_store_cookie($query, $box, $password)
				unless($self->{'cookie'});
			
			#Set the current box in the VOCP obj
			$Vocp->current_box($box);
			
			# Login ok
			return 1;
			
		} else { #Bad cookie
		
			$self->{'cookie'} = $query->cookie(-name => $Cookiename, value=>'');
			my $values = { 'login' => $Thiscgi };

			my $page = $self->_fill_tpl($values, $Templates{'badcookie'});

			$self->_display_tpl($page);

			exit(0);
		}
		
			
			
	} elsif (defined $passwd) { #First time login
	
		# Check that it is the correct password
		if ( $Vocp->check_password($box, $passwd) ) {
			
			# Stash the cookie
			$self->_store_cookie($query, $box, $passwd);
			
			#Set the current box in the VOCP obj
			$Vocp->current_box($box);
			
			# Login ok
			return 1;
		} else { #Bad password
		
			$self->error("Invalid login.");
			
		}
	} else { #no password and no cookie --  not logged in or did not enter password at login
	
		$self->error('Not logged in, please enter a box and password at the '
			. qq|<A HREF="$Thiscgi">login page</A>|);
		
	}
	
	#We should never make it here...
	
	return 0;
	
}
	
# error		
# Displays an error message in the browser
sub error {
	my $self = shift;
	my $msg = shift;
	my $exit = shift || '1';
	
	my $page = qq|Content-type: text/html\n\n|
		  .qq|<HTML>\n<HEAD><TITLE>VOCP Error</TITLE></HEAD>\n|
		  .qq|<BODY bgcolor="#003047">\n<H1><FONT COLOR="#cccc66" |
		  .qq|FACE="Helvetica, Times, Arial, sans-serif">Error</FONT></H1>|
		  .qq|<P><FONT COLOR="#cccc66" FACE="Helvetica, Times, Arial, sans-serif">$msg|
		  .qq|</FONT></P>\n|
		  .qq|<P><a href="javascript:history.go(-1)">|
		  .qq|<FONT COLOR="#cccc66" FACE="Helvetica, Times, Arial, sans-serif">|
		  .qq|Go back</FONT></a></P>\n|
		  .qq|</BODY>\n</HTML>\n\n|;
		  
	print $page;
	
	log_msg($msg);
	
	exit($exit);
	
}



sub _fill_tpl {
	my $self = shift;
	my $values = shift;
	my $tpl = shift
		|| $self->error("Must pass values and tpl to _fill_tpl");
	my $file;
	if ($tpl =~ /<!--\s+template/i)  { # It is not a file name - it is the template
		$file = $tpl;
	} else { # We need to fetch the tpl
		$file = $self->_get_file($tpl);
	}
		
	# Do the substitutions
	$file =~ s/{{([^}]+)}}/$values->{$1}/g;
	
	return $file;
	
}

sub _get_file {
	my $self = shift;
	my $filename = shift;
	
	my $file;
	open(FILE, "<$filename")
		|| $self->error("Can't open $filename: $!");
	
	{
		local $/;
		undef $/;
		$file = <FILE>;
		close(FILE);
	}
	
	return $file;
	
}

sub _display_tpl {
	my $self = shift;
	my $page = shift;
	my $extra = shift; #optional - used to have attachement
	my $contenttype = shift; # use if $extra set
	my $filename = shift; #use if $extra set
	
	my $html = "Content-type: text/html\n"
		  . ($self->{'cookie'} ? "Set-Cookie: $self->{'cookie'}\n\n" : "\n" )
		  . $page . "\n";

	
	my $output;
	if (defined $extra && $contenttype eq 'embed') { #Embeded
	
		$html =~ s|<\s*/\s*body\s*>|<EMBED NAME="Voicemail" TYPE="audio/x-wav" SRC="$WebSounddir/$filename"></EMBED></BODY>|i;
		#"
	} elsif (defined $extra) {
	
		$contenttype ||= 'application/octet-stream';
		
		$filename ||= 'voicemail';
		
		my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 );
 
		my $boundary =  join ("", @chars[ map { rand @chars } (1 .. 10) ]) . 'VOCP-boundary'; 
		$output =  qq|Content-type: multipart/x-mixed-replace;boundary=$boundary\r\n\r\n|
				.qq|--$boundary\n|
				. $html
				.qq|--$boundary\n|
				.qq|Content-type: $contenttype\n|
				.qq|Content-Disposition: attachment;|
				.qq|filename=$filename\n\n|
				. $extra
				.qq|\n--$boundary--\n|;
	} 
	
	$output ||= $html;
	
	print $output;
	
	return 1;
	
}
	
	
sub _number_to_img {
	my $self = shift;
	my $type = shift
		|| $self->error("Must pass numeric image type (small or large) to _number_to_img");
	my $number = shift;
	
	$self->error("Must pass a number to _number_to_img")
		unless (defined $number);
	
	log_msg("Converting $number to sequence of images")
		if $Debug;
	
	my @values = split (//, $number);
	
	my $numvals = scalar @values;
	
	my $html;
	while ($numvals < 3) {
	
		$html .= qq|<IMG SRC="$NUMimg{$type}{'off'}">|;
		
		log_msg("Inserted one empty space")
			if ($Debug > 1);
		
		$numvals++;		
	}
	
	
	foreach my $val (@values) {
	
		$html .= qq|<IMG SRC="$NUMimg{$type}{$val}" ALT="$val">|;
		
		log_msg("Inserted image $NUMimg{$type}{$val}")
			if ($Debug > 1);
	}
	
	return $html;
	
}
	
	
sub _crypt_login {
	my $self = shift;
	my $box = shift;
	my $password = shift;
	
	# A stolen cookie will work for only 1 day a year...
	my ($sec,$min,$hour,$mday,$mon,
	 	$year,$wday,$yday,$isdst) = localtime(time);
	my @chars = ('a' .. 'z', 'A' .. 'Z', '0' .. '9');
	
	my $salt = join ("", @chars[ map { rand @chars } (1 .. 5) ]);
	my $cipher = new Crypt::CBC( {
					'key'             => $CryptKey,
					'cipher'          => $CipherAlgo,
			});
	
	my $salt2 = join ("", @chars[ map { rand @chars } (1 .. 3) ]);
	my $crypted = $cipher->encrypt_hex("$password|$box|$salt|$hour|$mday|$salt2|$mon");
	
	return $crypted;
	
}


sub _store_cookie {
	my $self = shift;
	my $query = shift;
	my $box = shift;
	my $password = shift;
	
	my $query_cookie = $query->cookie($Cookiename);

	# If cookie already set in browser. Don't need to do anything
	if ($query_cookie) {
		
		# Optimisation for _check_login()
		$self->{'cookie_val'} = $query_cookie;
		
		return 1;
	} elsif (! defined ($password))
	{
		$self->error("Need to pass a password to store cookie");
	}
	
	my $cookie_val = $self->_crypt_login($box,$password);
	
	# Optimisation for _check_login()
	$self->{'cookie_val'} = $cookie_val;
	
	# Used to set cookie in _display_tpl()
	$self->{'cookie'} = $query->cookie(-name=>$Cookiename,
					   -value=> $cookie_val,
					   -expires=>'+1h',
					   );

	return 1;
	
}
	

sub swap_uid {
	my $self = shift;
	my $user = shift;
	
	$self->error("Must pass a user to swap to")
		unless ($user);
		
	my $uid = getpwnam($user);

	log_msg("Current uid: $>")
		if ($Debug > 1);

	$> = 0 if ($> != 0) ;

	log_msg("Current uid: $>")
		if ($Debug > 1);
	$self->error("Swapping to $user but $user doesn't seem to be in /etc/passwd")
		unless (defined $uid);
		
	$> = $uid;
	

	log_msg("Current uid: $>")
		if ($Debug > 1);

	log_msg("Swapped to user $user ($>)")
		if ($Debug);
	
}


sub log_msg {
	my $msg = shift;
	
	print STDERR "$0 [$$]:\t$msg\n";
	
	return 1;
}
