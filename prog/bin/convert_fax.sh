#!/bin/sh

DEFAULTTEMPDIR="/tmp";

FAXES=$1;
FORMAT=$2;
DESTDIR=$3;

USAGE="$0 FAXNAME FORMAT [DESTINATIONDIRECTORY] 
Where:
	FAXNAME is a (relative, possibly partial) g3 filename
	FORMAT is jpeg|gif|tga|pcx|bmp or other ppmtoXXX supported values";



#
#convert_fax
#
#Convert g3 faxes to other image formats manually (be sure to check VOCPhax)
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



if [[ $FAXES == "" ]]
then
	echo $USAGE
	exit 2;
fi

if [[ $FORMAT ==  "" ]]
then
	echo $USAGE
	exit 3;
fi

if [[ $DESTDIR == "" ]]
then
	TEMPDIR=$DEFAULTTEMPDIR
else
	TEMPDIR=$DESTDIR
fi

FINALCONV="ppmto$FORMAT";
  for i in `ls $FAXES*`
  do
    DESTFILE="$TEMPDIR/$i";
    echo $DESTFILE
    g3topbm $i > $DESTFILE.pbm
    $FINALCONV $DESTFILE.pbm > $DESTFILE.$FORMAT
    rm $DESTFILE.pbm
  done

exit 0

