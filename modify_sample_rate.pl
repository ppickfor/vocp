#!/usr/bin/perl

# Modifies the default sample rate of 8000 to SAMPLE

$Pvfdeftooldir = '/usr/bin';


my $Sample = shift
	|| die "$0 SAMPLE [PVFTOOLDIR]\nPlease enter a sample rate (e.g. 7200)";

my $Pvftooldir = shift || $Pvfdeftooldir;

unless (-x "$Pvftooldir/pvfspeed") {
	print "Can't find pvfspeed executable, please add the pvftooldir as an
arg\n";

	print "E.g. $0 7200 /usr/bin\n";

	exit(0);
}

die "Invalid sample rate $Sample"
	unless ($Sample =~ /^\d+$/);

die "Must run this from the top directory of the VOCP install"
	unless (-e "./messages");

# change name of files

my $cmd = qq{find messages/ -name "*.pvf" | xargs -i mv {} {}.$Sample};

system($cmd);

my @soundfiles = `find messages/ -name "*.pvf.$Sample"`;
print "Converting sound files...\n";
foreach my $file (@soundfiles) {
	unless ($file =~ /^([^.]+)\.(pvf\.[\w\d]+)$/) {
		print STDERR "Invalid filename $file\n";
		next;
	}
	my $base = $1;
	my $ext = $2;

	system("/bin/cat $base.$ext | $Pvftooldir/pvfspeed -s $Sample > $base.pvf");
	system("/bin/rm $file");
}

print "PVF files converted from 8000 to $Sample sample rate\n";

exit(0);
