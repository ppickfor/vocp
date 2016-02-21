#!/usr/bin/perl

# This program is meant to be run during the VOCP
# ./install_vocp.pl
# Run it as root, while connected to the internet to
# fetch the modules from CPAN
use CPAN;
use lib '.';

CPAN::Shell->install('Bundle::VOCPDep');
