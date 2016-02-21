use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'VOCP',
    'VERSION_FROM'	=> 'VOCP.pm', # finds $VERSION
    'PREREQ_PM'		=> { 
						'XML::Mini'	=> 1.2,
						}, # e.g., Module::Name => 1.1
);
