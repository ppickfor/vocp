#!/usr/bin/perl 

=head2 date.pl - example for VOCP command shells

Copyright (C) Pat Deegan 2000
Distributed as part of the VOCP system, under the terms of 
the GNU GPL, see the LICENSE file.

Outputs two lines, the current hour and minute.

When used from a command shell, the caller will hear the current
time if the return of date.pl is set to 'output'.  If it is set
to 'exit', the caller will hear 'ninety-nine', the exit value
of the program.

=cut

use strict;

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime(time);

print "$hour\n$min";

exit(99);

