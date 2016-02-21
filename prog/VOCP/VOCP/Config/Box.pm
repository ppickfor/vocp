package VOCP::Config::Box;

use strict;

use VOCP::Vars;
use XML::Mini::Document;
use FileHandle;

use vars qw {
	$VERSION
	$UseShadow
	%ShadowKeys
};

$VERSION = $VOCP::Vars::VERSION;


$UseShadow = 1;

%ShadowKeys = (
		'password'	=> 1,
	);
	

use strict;

=head1 VOCP::Config::Box

=head1 SYNOPSIS

=head1 ABSTRACT


=head1 DESCRIPTION

The VOCP::Config::Box module is used to parse and generate VOCP boxes.conf files that look
like:

 
<VOCPBoxConfig>
 <boxList>
  <box number="001">
   <message> root.rmd </message>
   <type> none </type>
   <password> password </password>
   <owner> pat </owner>
   <name> Main menu for Eng. dept. </name>
   <numDigits> 2 </numDigits>
   <branch> 011,012,200 </branch>
   <email> pat@psychogenic.com </email>
   <autojump> 123 </autojump>
   <restricted> secret </restricted>
   <restrictLoginFrom> 5551212 </restrictLoginFrom>
   <commandList>
  	<command selection="100">
	  <input> text </input>
	  <return> output </return>
	  <run> ip.pl eth0 </run>
	</command>
	<command selection="200">
	  ...
	</command>
   </commandList>
  </box>
 
  <box number="100">
   ...
  </box>
 
 </boxList>
</VOCPBoxConfig>


It uses MiniXML (the XML::Mini module available from CPAN or 
http://minixml.psychogenic.com) to do so.




=head1 AUTHOR

LICENSE

    VOCP::Config::Box module, part of the VOCP voice messaging system package.
    Copyright (C) 2002 Patrick Deegan
    All rights reserved
    
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


Official VOCP site: http://VOCPsystem.com

Contact page for author available in contact section at 
http://www.psychogenic.com/



=head2 new [FILE]

Creates and returns a new instance of VOCP::Config::Box.

If FILE is passed, will use a MiniXML::Document to read and parse the 
XML config file.

=cut

sub new {
	my $class = shift;
	my $file = shift; # optionally read from file
	
	my $self = {};
	bless $self, ref $class || $class;
	
	$self->{'_miniXMLDoc'} = XML::Mini::Document->new();
	
	
	if ($file)
	{
		$self->readConfig($file);
	}
	
	return $self;
}

=head2 fromHash HREF

Initialise the object from hash ref HREF.

=cut

sub fromHash {
	my $self = shift;
	my $href = shift || return undef;
	
	
	my $boxCount = 0;
	
	my ($shadowRoot, $shadowConf, $shadowBoxList);
	$self->{'_miniXMLDoc'}->init(); # reset the XML Document
	my $rootEl = $self->{'_miniXMLDoc'}->getRoot();
	my $header = $rootEl->header('xml');
	$header->attribute('version', '1.0');
	my $vocpConf = $rootEl->createChild('VOCPBoxConfig');
	my $boxList = $vocpConf->createChild('boxList');
	
	if ($UseShadow)
	{
		$self->{'_miniXMLShadow'} = XML::Mini::Document->new();
		$shadowRoot = $self->{'_miniXMLShadow'}->getRoot();
		$shadowConf = $shadowRoot->createChild('VOCPBoxConfig');
		$shadowBoxList = $shadowConf->createChild('boxList');
		
	} else {
		delete $self->{'_miniXMLShadow'};
	} 
	
	foreach my $boxNumber (sort keys %{$href})
	{
		my $shadowBox;
		my $newBox = $boxList->createChild('box');
		
		$newBox->attribute('number', $boxNumber);
		
		my $boxConf = $href->{$boxNumber};
		
		my @attributes = ('name', 'type','message', 'password', 'owner', 'email', 'branch', 'autojump', 'numDigits', 
					'restrictFrom', 'restrictLoginFrom', 
					 'restricted', 'file2fax', 'script', 'input', 'return', 'members');
					
		foreach my $attrib (@attributes)
		{
			next unless (defined $boxConf->{$attrib});
			my $value = $boxConf->{$attrib};
			
			next if ($value eq '' || $value eq 'none');
			if ($UseShadow && $ShadowKeys{$attrib})
			{
				unless ($shadowBox)
				{
					$shadowBox = $shadowBoxList->createChild('box');
					$shadowBox->attribute('number', $boxNumber);
				}
				$shadowBox->createChild($attrib, $value);
			} else {
				$newBox->createChild($attrib, $value);
			}
		}
		
		if ($boxConf->{'type'} && $boxConf->{'type'} =~ m|^command$|i && defined $boxConf->{'commands'})
		{
			my $commandList = $newBox->createChild('commandList');
			
			foreach my $selection (sort keys %{$boxConf->{'commands'}})
			{
				my $commandElement = $commandList->createChild('command');
				$commandElement->attribute('selection', $selection);
				
				my @cmdAttributes = ('input', 'return', 'run');	
				foreach my $cmdAttrib (@cmdAttributes)
				{
					next unless (defined $boxConf->{'commands'}->{$selection}->{$cmdAttrib});
					
					my $cmdChild = $commandElement->createChild($cmdAttrib,
									 $boxConf->{'commands'}->{$selection}->{$cmdAttrib});
									 
				} # end loop over selection attributes
				
				
			} # end loop over selections for this command shell
			
		} # end if this is a command shell and commands are set
		
		$boxCount++;
		
	} # end loop over each box
			
	
	return $boxCount;
	
	
}


sub readConfig {
	my $self = shift;
	my $file = shift;
	
	return VOCP::Util::error("Must pass a filename to VOCP::Config::Box::readConfig()") unless ($file);
	
	return VOCP::Util::error("VOCP::Config::Box::readConfig() Can't find or can't read file '$file'")
		unless (-e $file && -r $file);
	
	my $children = $self->{'_miniXMLDoc'}->fromFile($file);
	
	unless ($children)
	{
	
		VOCP::Util::log_msg("VOCP::Config::Box::readConfig() Could not extract any children from XML file '$file'");
		return {};
	}
		
	
	my $shadowfile = "$file.shadow";
	if (-e $shadowfile && -r $shadowfile)
	{
		$self->readShadow($shadowfile);
	}
		
	return $self->toHash();
	
}


# Shadow files may exist for any attribute ('password' by default)
# The must have the form:
# BOXNUM:ATTRIBNAME:ATTRIBVALUE
# and can use lines starting with '#' for comments.
sub readShadow {
	my $self = shift;
	my $shadowfile = shift;
	
	return VOCP::Util::error("VOCP::Config::Box::readShadow() Can't find or can't read file '$shadowfile'")
		unless (-e $shadowfile && -r $shadowfile);
	$self->{'_miniXMLShadow'} =  XML::Mini::Document->new();
	my $children = $self->{'_miniXMLShadow'}->fromFile($shadowfile);
	
	return VOCP::Util::error("VOCP::Config::Box::readShadow() Could not extract any children from XML file '$shadowfile'")
		unless ($children);
		
	$self->{'_shadowKeys'} = {};
	

	
}
	

sub writeConfig {
	my $self = shift;
	my $file = shift;
	
	
	return VOCP::Util::error("Must pass a filename to VOCP::Config::Box::writeConfig()") unless ($file);
	
	return VOCP::Util::error("VOCP::Config::Box::writeConfig() Can't write to file '$file'")
		if (-e $file && ! -w $file);
	
	my $fcount = 0;
	my $outfileFh = FileHandle->new();
	
	if (! $outfileFh->open(">$file"))
	{
		return VOCP::Util::error("VOCP::Config::Box::writeConfig() Could not open '$file' for write: $!");
	}
	$outfileFh->autoflush();
	$outfileFh->print($self->toXMLString());
	
	$outfileFh->close();
	$fcount++;
	
	if ($self->{'_miniXMLShadow'})
	{
		my $shadowOutFh = FileHandle->new();
		my $oldumask = umask(077);
		unless ($shadowOutFh->open(">$file.shadow"))
		{
			return VOCP::Util::error("VOCP::Config::Box::writeConfig() Could not open '$file.shadow' for write: $!");
		}
		$shadowOutFh->autoflush();
		$shadowOutFh->print($self->{'_miniXMLShadow'}->toString());
		$shadowOutFh->close();
		$fcount++;
	}
	
	return $fcount;
}

=head2 toHASH

Converts currently stored internal config to a hash ref of the form:
 

 	BOXNUMBER1	=> {
				'message'	=> MESSAGEFILE,
				'type'		=> BOXTYPE,
				'password'	=> PASSWORD,
				'owner'		=> OWNER,
				'branch'	=> BRANCHSTRING,
				'email'		=> EMAIL,
				'autojump'	=> AUTOJUMP,
				'restricted'	=> RESTRICTED,
				'restrictFrom'	=> RESTRICTNUMREGEX,
				'numDigits'	=> NUMERICALVAL,
				'name'		=> BOXNAME,
				'file2fax'	=> FILEPATH,
				'commands'	=> {
							SELECTION1	=> {
									'input'	=> INPUT,
									'return'=> RETURN,
									'run'	=> RUN,
									}
							SELECTION2	=> { ... }
						},
			},
	BOXNUMBER2 	=> { ... },
	
	...

Where UPPERCASE values are replaced by actual values.  Keys will only be set where appropriate.

=cut


sub toHash {
	my $self = shift;
	
	my $hash = $self->miniXMLToHash() || return undef;
	
	if ($self->{'_miniXMLShadow'})
	{
		my $shadow = $self->miniXMLToHash($self->{'_miniXMLShadow'});
		
		
		while (my ($boxnum, $shadowHash) = each %{$shadow})
		{
			unless (defined $hash->{$boxnum})
			{
				VOCP::Util::log_msg("Shadow value found for undefined box $boxnum - skipping");
				next;
			}
			while ( my ($shadowKey, $shadowVal) = each %{$shadowHash})
			{
					
				$hash->{$boxnum}->{$shadowKey} = $shadowVal;
				$self->{'_shadowKeys'}->{$shadowKey}++;
			}
		}
		
	}
	
	return $hash;
}
	


sub miniXMLToHash {
	my $self = shift;
	my $document = shift || $self->{'_miniXMLDoc'};
	

	my $boxList = $document->getElementByPath('VOCPBoxConfig/boxList');
	
	unless ($boxList)
	{
	
		VOCP::Util::log_msg("VOCP::Config::Box::toHash() Could not find a 'boxList' element in XML document.");
		return {};
	}
		
		
	my $boxes = $boxList->getAllChildren('box');
	
	return undef unless (scalar @{$boxes});
	
	my $retHash = {};
	my $boxCount = 0;
	foreach my $box (@{$boxes})
	{ 
		my $number = $box->attribute('number');
		
		unless (defined $number)
		{
			VOCP::Util::Log("VOCP::Config::Box::toHash(): Invalid box entry - no 'number' attribute set. Skipping.");
			next;
		}
		
		my $boxChildren = $box->getAllChildren();
		
		my $boxHash = {};
		
		for (my $i=0; $i<= scalar @{$boxChildren}; $i++)
		{
			next unless ($boxChildren->[$i]);
			
			my $name = $boxChildren->[$i]->name();
			
			next unless (defined $name);
			
			my $value = $boxChildren->[$i]->getValue();
			
			$boxHash->{$name} = $value;
		}
		
		
		if (defined $boxHash->{'type'} && $boxHash->{'type'} =~ m|^command$|i)
		{ 
			my $cmdHash = $self->_extractCommandList($box);
		
			if ($cmdHash && scalar keys %{$cmdHash})
			{
				$boxHash->{'commands'} = $cmdHash;
			}
			
		} # end if this is a command box
	
		$retHash->{$number} = $boxHash;
		
	} # end foreach over all box entries
	
	return $retHash;
	
}


	
	

sub _extractCommandList {
	my $self = shift;
	my $boxElement = shift || return undef;
				
	my $comList = $boxElement->getElement('commandList');
	
	return undef unless ($comList);
	
	my $retHash = {};
	my $commands = $comList->getAllChildren('command');
	foreach my $cmd (@{$commands})
	{
		my $selection = $cmd->attribute('selection');
		
		unless (defined $selection)
		{
			VOCP::Util::Log("VOCP::Config::Box::toHash(): Invalid command entry - no 'selection' attribute set "
					. ' in box number ' . $boxElement->attribute('number') . "...Skipping.");
			next;
		}
		
		my $cmdHash = {};
		my @attributes = ('input', 'return', 'run');	
		foreach my $attrib (@attributes)
		{
			my $element = $cmd->getElement($attrib);
			
			if ($element)
			{
				my $value = $element->getValue();
				if (defined $value)
				{
					$cmdHash->{$attrib} = $value;
				}
			}
			
		} # end foreach over each command selection entry attribute
		
		$retHash->{$selection} = $cmdHash;
		
	} # end foreach over each command selection entry
	
	return $retHash;
	
}



sub toXMLString {
	my $self = shift;
	
	return $self->{'_miniXMLDoc'}->toString();
	
}



1;

__END__
