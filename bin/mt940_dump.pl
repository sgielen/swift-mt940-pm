#!/usr/bin/perl
use strict;
use warnings;
use lib '../lib';
use lib 'lib';
use SWIFT::MT940;
use Data::Dumper;

my ($file) = @ARGV;
if(!$file) {
	die "Usage: $0 <file>";
}

open my $fh, $file or die $!;
my $body = "";
while(<$fh>) {
	$body .= $_;
}
close $file;

eval {
	my $mt940 = SWIFT::MT940->parse($body);
	print Dumper([$mt940->get_statements()]);
};
if($@) {
	warn "Read failed: " . Dumper($@);
	exit;
}
