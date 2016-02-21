#!/usr/bin/perl

use FileHandle;


my $vocp = '/usr/local/vocp/bin/vocp.pl';

my ($inputReadfh, $inputWritefh) = FileHandle::pipe;
my ($outputReadfh, $outputWritefh) = FileHandle::pipe;

my $input = $inputReadfh->fileno();
my $output = $outputWritefh->fileno();

my $pid = fork();

if (! $pid)
{
	exec("export VOICE_INPUT=$input; export VOICE_OUTPUT=$output; export VOICE_PID=$$; $vocp");

} else {
	
	$done = 0;
	while (! $done)
	{
	print STDOUT "vgetty:";
	my $vgettyIn = <STDIN>;
	chomp($vgettyIn);
	$done++ if ($vgettyIn =~ /DONE/);

	print $inputWritefh "$vgettyIn\n";

	my $vocpOut = <$outputReadfh>;
	chomp($vocpOut);

	print STDOUT "vocp: $vocpOut\n";
	}
}

