#!/usr/bin/perl

=head1 NAME

cryptpass.pl - encrypt a string using crypt.

=head1 AUTHOR INFORMATION

LICENSE

    cryptpass.pl, part of the VOCP voice messaging system.
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

my @chars = ('a' .. 'z', 'A' .. 'Z', '0'..'9');

print "VOCP password crypt\n";
print "Enter a password to encrypt: ";
my $passwd = <STDIN>;
chomp $passwd;

my $salt = join("", @chars[ map { rand @chars } (1 .. 2) ]);

print "Crypted : " . crypt($passwd, $salt) . "\n\n";

