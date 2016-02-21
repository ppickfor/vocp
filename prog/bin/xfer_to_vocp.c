/* xfer_to_vocp.c simple wrapper to allow setuid operation of xfer_to_vocp.pl
**
** Usefull for sending a virtual ring signal to vgetty, such that it will
** immediately launch vocp.
**
** To be useful, this program must be compiled -o xfer_to_vocp and installed
** owned by root:vocp mode 4755 (setuid)
**
**    xfer_to_vocp.c, part of the VOCP voice messaging system
**    Copyright (C) 2003 Patrick Deegan, Psychogenic.com
**    All rights reserved.
**
**    This program is free software; you can redistribute it and/or modify
**    it under the terms of the GNU General Public License as published by
**    the Free Software Foundation; either version 2 of the License, or
**    (at your option) any later version.
**
**    This program is distributed in the hope that it will be useful,
**    but WITHOUT ANY WARRANTY; without even the implied warranty of
**    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**    GNU General Public License for more details.
**
**    You should have received a copy of the GNU General Public License
**    along with this program; if not, write to the Free Software
**    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
**
**
**
*/

#include <unistd.h>

#define XFERTOVOCP "/usr/local/vocp/bin/xfer_to_vocp.pl"

int main (void)
{
	char * av[1];
	av[0] = NULL;
	execv(XFERTOVOCP, av);
	
	/* Never Get here */
	exit(254);
}
