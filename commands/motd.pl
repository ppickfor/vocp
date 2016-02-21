#!/usr/bin/perl

=head2 motd.pl

This simple program demonstrates the use of script boxes or commands that use the TTS output.
You must ensure that festival is correctly installed and that txttopvf is configured to point
to the festival text2wave program.

=cut

my ($name,$passwd,$uid,$gid,
                       $quota,$comment,$gcos,$dir,$shell,$expire) = getpwuid($>);


print "Do not worry my friend... You will eventually achieve success configure ing V.O.C.P.  Hooooooray!!!!\n";
print "This script was run as user '$name' with U.I.D. $uid.  Goodbye.\n";

exit(0);
