package VOCP::Strings;
use VOCP::Vars;

use strict;

use vars qw {
		%Strings
		$VERSION
	};
$VERSION = $VOCP::Vars::VERSION;	


=head1 VOCP::Strings

=head1 NAME

VOCP::Strings - contains strings used by multiple portions of VOCP

=head1 AUTHOR

LICENSE

    VOCP::Message module, part of the VOCP voice messaging system package.
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

=cut





%Strings = (
		'en'	=> {
				'file'		=> 'File',
				'newbox'	=> 'New Box...',
				'editbox'	=> 'Edit Box...',
				'delbox'	=> 'Delete Box',
				'delallboxes'	=> 'Delete All Boxes',
				'help'		=> 'Help',
				'quit'		=> 'Quit',
				'about'		=> 'About',
				'version'	=> 'Version',
				'abouttitle'	=> 'About...',
							
				'versiontitle'	=> 'Version...',
				
				'boxconfinfo'	=> "Welcome to VOCP boxconf!\nDoubleclick on a box to edit, select an "
						   . "existing box\nto delete or create a new box.",		
				'save'		=> 'Save',
				'edit'		=> 'Edit',
				'boxlabel'	=> "Existing boxes",
				'cmdboxlabel'	=> "Command\nboxes",
				'faxboxlabel'	=> "Fax-on-\ndemand\nboxes",
				'bottomlabel'	=> "\nSee http://www.VOCPsystem.com for\ninstructions and the latest version.\n\n",
				'reallydeletetitle'	=> 'Confirmation',
				'reallydelete'	=> 'Are you certain you wish to delete ',
				'allboxes'	=> 'all boxes',
				'boxlisttitle'	=>  'num  type     name        owner          message               branch',
				'addbox'	=> 'Add Box',
				'entervals'	=> 'Enter your values for the box below.',
				'box'	=> 'Box',
				'noboxes'	=> 'No Boxes',
				'num'		=> 'Num:',
				'name'		=> 'Name:',
				'numDigits'	=> 'Number of digits (default 1):',
				'cndrestrict' 	=> 'CID Restrictions (leave empty to allow from anywhere)',
				'restrictLoginFrom' => 'Only login from:',
				'restrictFrom' => 'Public access from:',
				'message'	=> "Message",
				'owner'	=> 'Owner:',
				'passwd' 	=> 'Password:',
				'email'		=> 'Email:',
				'callflow'	=> 'Call Flow:',
				'branch'	=> 'Branch:',
				'autojump'	=> 'AutoJump:',
				'restricted'	=> 'Restricted:',
				'overwrite?'	=> "Proceed and overwrite\n existing box ",
				'error'		=> 'Error',
				'erroroccur'	=> "An error has occured.\n",
				'cmdshell'	=> "Command Shell",
				'configuration'	=> 'configuration',
				'newcmd'	=> 'New Selection',
				'editcmd'	=> 'Edit Selection',
				'delcmd'	=> 'Delete Selection',
				'cmdtitle'	=> 'New/Edit Selection',
				'numselerror'	=> 'Must enter a numeric selection',
				'cmdrunerror'	=> "Must enter a command to\nrun for this selection",
				'overwritesel'	=> "Proceed and overwrite\n existing selection " ,
				'confirmation'	=> 'Confirmation',
				'faxondemand'	=> 'Fax-on-demand',
				'enterfaxfile'	=> "Enter the file to send for\nfax-on-demand box " ,
				'errorg3faxfile'	=> "Must enter a g3 file to send\nfor fax-on-demand box",
				'absfaxfile'	=> "Must enter absolute path\nfor fax-on-demand file",
				'cmdinst'	=> "Enter values for the\ncommand box",
				'cmdsel'	=> 'Sel:',
				'cmdinput'	=> 'Input:',
				'cmdrun'	=> 'Run:',
				'cmdreturn'	=> 'Return:',
				'saveconfig'	=> 'Save current config to',
				'errorneedfname'	=> "Must enter a filename to save\n",
				'errorcantwrite'	=> "Don't have permission to write to ",
				'changesmade'	=> "Modifications have been made.\nReally discard changes?",				
				
				
				'export'	=> 'Export...',
				'play'		=> 'Play',
				'stop'		=> 'Stop',
				'delete'	=> 'Delete',
				'forward'	=> 'Forward...',
				
				'askpasstitle'	=> 'Enter Password',
				'askpasstext'	=> 'Enter Password',
				'exporttitle'	=> 'Export Message',
				'exporttext'	=> 'Enter File Name',
				'emailfrom'	=> 'You have an e-mail from ',	
				'script'	=> 'Script',
				
				'enterscript'	=> 'Enter the path to the executable',
				'errornoscript'	=> 'You must enter an executable location',
				
				'absscriptfile'	=> "You must enter the FULL path\nto the executable",
				'toggleEmail2Vm'	=> 'Toggle email2vm',
				'awaitingcall'	=> "Waiting For Call",
				'create'	=> 'Create',
				'sendqueue'	=> 'Send Queue',
				'inqueue'	=> 'InBox',
				'outqueue'	=> 'OutBox',
				'selectdir'	=> 'Select Dir',
				'emptyqueue'	=> 'Empty',
				'fax'		=> 'Fax',
				'exit'		=> 'Exit',
				'view'		=> 'View',
				'zoom'		=> 'Zoom',
				'in'		=> 'In',
				'out'		=> 'Out',
				'viewXloadImage'	=> 'xload Image',
				'viewXloadImagefull'	=> 'xload Image %100',
				'preview'	=> 'Preview',
				'open'		=> 'Open',
				'newmessage'	=> 'New message for box ',
				'incomingcall'	=> 'Incoming call ',
				'from'		=> 'from ',
				
				
				
				
				
				
				
			},
		
		'fr'	=> {
				'file'		=> 'Fichier',
				'newbox'	=> 'Nouvelle Boite...',
				'editbox'	=> 'Editer...',
				'delbox'	=> 'Supprimer',
				'delallboxes'	=> 'Supprimer Toutes Boites',
				'help'		=> 'Aide',
				'quit'		=> 'Quitter',
				'about'		=> 'A propos',
				'version'	=> 'Version',
				'abouttitle'	=> 'A propos de boxconf...',
				
				'versiontitle'	=> 'Version...',
				'boxconfinfo'	=> "Bienvenue a VOCP boxconf!\nDouble-clickez sur une boite pour l'editer ou selectioner\n"
						   .'uned boite existante a suprimmer ou cree une nouvelle boite.',
				'save'		=> 'Sauvegarder',
				'edit'		=> 'Editer',
				'boxlabel'	=> "Boites",
				'cmdboxlabel'	=> "Boites\nde commandes",
				'faxboxlabel'	=> "Boites\nFax-on-\ndemand",
				'bottomlabel'	=> "\nVisitez http://www.VOCPsystem.com pour\nplus d'info et la derniere version.\n\n",
				'reallydeletetitle'	=> 'Confirmation',
				'reallydelete'	=> 'Etes-vous certain de vouloir supprimer ',
				'allboxes'	=> 'toutes les boites',
				'boxlisttitle'	=>  'num   type           owner          message            branch',
				'addbox'	=> 'Creer',
				'entervals'	=> 'Entrez les valeurs pour cette boite.',
				'box'	=> 'Boite:',
				
				'noboxes'	=> 'No Boxes',
				'num'	=> 'Num:',
				'name'	=> 'Nom:',
				'numDigits'	=> 'Nombre de touche (default 1):',
				'cndrestrict' => 'CID Restrictions (regex)',
				'restrictLoginFrom' => 'login restrain de:',
				'restrictFrom' => 'Access restrain de:',
				'message'	=> "Message",
				'owner'	=> 'Owner:',
				'passwd' 	=> 'Password:',
				'email'		=> 'Email:',
				'callflow'	=> 'Call Flow:',
				'branch'	=> 'Branch:',
				'autojump'	=> 'AutoJump:',
				'restricted'	=> 'Restricted:',
				'overwrite?'	=> "Continuer et effacer\n la boite ",
				'error'		=> 'Erreur',
				'erroroccur'	=> "Une erreur est parvenue.\n",
				'cmdshell'	=> "Command Shell",
				'configuration'	=> 'configuration',
				'newcmd'	=> 'Nouveau',
				'editcmd'	=> 'Editer',
				'delcmd'	=> 'Supprimer',
				'cmdtitle'	=> 'Creer/Editer',
				'numselerror'	=> 'Vous devez entrer une selection numerique',
				'cmdrunerror'	=> "Vous devez remplir l'entrer\n'run' pour cette selection",
				'overwritesel'	=> "Continuer et effacer\n la selection " ,
				'confirmation'	=> 'Confirmation',
				'faxondemand'	=> 'Fax-on-demand',
				'enterfaxfile'	=> "Entrer le fichier a faxer\npour la boite " ,
				'errorg3faxfile'	=> "Vous devez entrer un fichier a envoyer\npour la boite fax-on-demand ",
				'absfaxfile'	=> "Vous devez entrer un path complet pour\nle fichier fax-on-demand",
				'cmdinst'	=> "Entrer les valeur pour la\ncommand box",
				'cmdsel'	=> 'Sel:',
				'cmdinput'	=> 'Input:',
				'cmdrun'	=> 'Run:',
				'cmdreturn'	=> 'Return:',
				'saveconfig'	=> 'Enregistrer la configuration dans',
				'errorneedfname'	=> "Vous devez entrer un nom de fichier\n",
				'errorcantwrite'	=> "Pas de permissions d'ecriture ",
				'changesmade'	=> "Il y a eu des modifications.\nDiscarter?",	
				
				'cmdinst'	=> "Entrer les valeur pour la\ncommand box",
				'cmdsel'	=> 'Sel:',
				'cmdinput'	=> 'Input:',
				'cmdrun'	=> 'Run:',
				'cmdreturn'	=> 'Return:',
				'saveconfig'	=> 'Enregistrer la configuration dans',
				'errorneedfname'	=> "Vous devez entrer un nom de fichier\n",
				'errorcantwrite'	=> "Pas de permissions d'ecriture ",
				'changesmade'	=> "Il y a eu des modifications.\nDiscarter?",				
							
				'export'	=> 'Exporter...',
				'askpasstitle'	=> 'Mot de passe',
				'askpasstext'	=> 'Entrer votre mot de passe',
				'exporttitle'	=> 'Exporter',
				'exporttext'	=> 'Entrer le nom du fichier a creer',		
				'emailfrom'	=> 'Vous avez un email de ',	
					
				'script'	=> 'Script',
				'enterscript'	=> 'Entrez le path de l\'executable',
				'errornoscript'	=> 'You must enter an executable location',
				'absscriptfile'	=> "Vous devez entrer un path complet pour\nle fichier a executer",
				'toggleEmail2Vm'	=> 'Toggle email2vm',
				'awaitingcall'	=> "En attente d'appel",
				'create'	=> 'Creer',
				'sendqueue'	=> 'Envoyer',
				'inqueue'	=> 'Reception',
				'outqueue'	=> 'Envoi',
				'selectdir'	=> 'Selectioner Repertoire',
				'emptyqueue'	=> 'Vider',
				'fax'		=> 'Fax',
				'exit'		=> 'Quitter',
				'view'		=> 'Visionner',
				'zoom'		=> 'Zoom',
				'in'		=> 'In',
				'out'		=> 'Out',
				'viewXloadImage'	=> 'xload Image',
				'viewXloadImagefull'	=> 'xload Image %100',
				'preview'	=> 'Visionner',
				'open'		=> 'Ouvrir',
				'newmessage'	=> 'Nouveau message pour la boite ',
				'incomingcall'	=> 'Appel entrant ',
				'from'		=> 'provenant de ',
				
				
				
				
			},
		
	);


1;
