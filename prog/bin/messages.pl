#!/usr/bin/perl
use strict;
my $License = join( "\n",  
qq|##################### messages.pl #######################|,
qq|######                                            #######|,
qq|######      Copyright (C) 2000  Pat Deegan        #######|,
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
qq|#   You may contact the author, Pat Deegan, by email    #|,
qq|#   at vocp\@psychogenic.com.  My home page           #|,
qq|#   may be found at http://pat.psychogenic.com          #|,
qq|#                                                       #|,
qq|#########################################################|,
);



=head1 NAME

messages.pl - VOCP console message retrieval, essentially deprecated.

=head1 AUTHOR INFORMATION

LICENSE

   messages.pl, part of the VOCP voice messaging system.
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


# use lib '/etc/mgetty+sendfax/vocp';
use VOCP;
use VOCP::Util;

my $Rm;
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
$ENV{'CDPATH'} = '';
$ENV{'ENV'} = '';
{
	my $options = {
			'genconfig' => '/etc/vocp/vocp.conf',
		};
		
		
	my $Vocp = VOCP->new($options)
		|| VOCP::Util::error("Unable to create new VOCP");

	$Rm = $Vocp->{'programs'}->{'rm'} || '/bin/rm';

	print "\n\n$License\n";
	
	print "\nEnter boxnumber: ";
	
	my $box = <STDIN>;
	chomp($box);
	
	# Running setgid so we untaint the input
	VOCP::Util::error("Invalid box number: $box")
		unless ($box =~ /^(\d+)$/ && $Vocp->valid_box($box));
	$box = $1;
		
	my $messages = $Vocp->list_messages($box);
	
	my $nummsg = scalar @{$messages};
	
	if (! $nummsg ) {
		print "You don't seem to have any messages in box $box\n";
		
		exit(0);
	} else { #We do have some messages
		my $menu = qq|\nEnter a message number to hear it,\n|
			  .qq|enter 'd XX' (where XX is a message number) to\n|
			  .qq|delete it and use 'l' to list all messages.\n|
			  .qq|Enter 'q' to quit.\n|;
			  
		print "You have $nummsg message"
			. ($nummsg > 1 ? 's' : '') . "\n$menu";
		
		my $continue = 1;
		do {
			print "> ";
			my $selec = <STDIN>;
			chomp($selec);
				
			if ($selec =~ /^\d+$/) {
				play_msg($messages, $Vocp->{'inboxdir'}, $selec);
			} elsif ($selec =~ /^d/i) { #Delete
			
				delete_msg($messages, $Vocp->{'inboxdir'}, $selec);
				
				$messages = $Vocp->list_messages($box);
				
				$nummsg = scalar @{$messages};
				
				print "You have $nummsg message"
					. ($nummsg > 1 ? 's' : '') . "\n$menu";
			
			} elsif ($selec =~ /^l/i) { #List
			
				my $list = $Vocp->list_messages($box, 'LONG');
				print "\n";
				my $i = 1;
				foreach my $msg ( @{$list} ) {
					print "$i\t$msg\n";
					$i++;
				}
				print "\n";
				
			
			} elsif ($selec =~ /^q/i) { #quit
			
				$continue = 0;
			} else { #invalid selection
			
				print "\nInvalid selection\n$menu";
			}
		} while ($continue);
		
		
	}
	
	exit (0);
	
}

sub play_msg {
	my $messages = shift;
	my $inboxdir = shift;
	my $selec = shift;
	
	my $num = $selec - 1; # It's an array
	
	unless (defined $messages->[$num]) {
		print "Invalid selection: $selec\n";
		return;
	}
	
	my $file = VOCP::full_path($messages->[$num], 
		$inboxdir); 
	
	$file = untaint_file($file, $inboxdir);
		
	system("rmdtopvf $file | pvfspeed -s 8000 | pvftobasic > /dev/audio");
	
	return;
	
}

	
sub delete_msg {
	my $messages = shift;
	my $inboxdir = shift;
	my $selec = shift;
	
	
	if ($selec =~ /^d\s+(\d+)\s*$/i ) { #Del single msg
	
		my $msg = $1;
		my $num = $msg - 1; #an array
		
		unless ($messages->[$num]) {
			print "Invalid selection: $num\n";
			return;
		}
		
		my $file = VOCP::full_path($messages->[$num], 
			$inboxdir, 'SAFE'); 
		
		$file = untaint_file($file, $inboxdir);
		# print "Deleting $file\n";		
		system("$Rm -f $file");
		
	} elsif ( $selec =~ /^d\s+(\d+)-(\d+)\s*$/i ) { #Deleting range
	
		my $first = $1;
		my $sec = $2;
		my $start = $first - 1; #array
		my $stop = $sec - 1;
		
		unless ( ($start < $stop) && ($start >= 0)
			 && (defined $messages->[$start])
			 && (defined $messages->[$stop]) ) {
			 
			 print "Invalid range: $first-$sec\n";
			 return;
		}
		
		my $i;
		for ($i = $start; $i <= $stop; $i++) {
		
			my $file = VOCP::full_path($messages->[$i], 
			$inboxdir, 'SAFE'); 
		
			$file = untaint_file($file, $inboxdir);
			# print "Deleting $file\n";		
			system("$Rm -f $file");
		}
	} else {
		print "Invalid selection: $selec\n";
	}
	
	return;
	
}

sub untaint_file {
	my $file = shift;
	my $inboxdir = shift;
	
	if ($file =~ m|^($inboxdir(/)?\d+-\d+\.rmd)|) {
		$file = $1;
	} else { 
		return "";
	}
	
	return $file;
	
}
	
	
