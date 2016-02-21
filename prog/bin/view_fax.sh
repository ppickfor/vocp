#!/bin/sh

USAGE="$0 FAXFILE [SCALETO] - Where FAXFILE is the path to a FAX file in g3 format (of the partial name) and SCALETO is a numerical value between 0-1";
DEFAULTSCALE="0.5"
IMAGEVIEWER="xloadimage stdin"

#
#view_fax
#
#View g3 fax files manually (be sure to check VOCPhax)
#
#
#    view_fax.sh, part of the VOCP voice messaging system
#    Copyright (C) 2002 Patrick Deegan, Psychogenic.com
#    All rights reserved.
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#
#Visit the official site: http://www.VOCPsystem.com or get in touch with me through
#the about page at http://www.psychogenic.com.
#


FAXFILE=$1
SCALETO=$2

if [[ $SCALETO == "" ]]
then
	SCALETO=$DEFAULTSCALE
fi

if [[ $FAXFILE == "" ]]
then
	echo $USAGE;
	exit 2
fi

PATH="/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin:/usr/X11R6/bin"
export PATH

for i in `ls $FAXFILE*`
do
	
	g3topbm $i | pnmscale $SCALETO | $IMAGEVIEWER
done
