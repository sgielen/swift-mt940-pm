#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 2;

BEGIN { use_ok("SWIFT::MT940"); }

my $rabo_file = <<EOF;
:940:
:20:100618/42182
:25:0147458692EUR
:28C:164
:60F:C100617EUR33,66
:61:1006180618C1,00NMSCNONREF
:86:TEST ROY
:62F:C100618EUR34,66
:64:C100618EUR34,66
:65:C100621EUR34,66
:65:C100622EUR34,66
:65:C100623EUR34,66
:65:C100624EUR34,66
EOF

SKIP: {
eval {
	my $obj = SWIFT::MT940->parse($rabo_file);
	use Data::Dumper;
	print Dumper($obj);
	pass("Rabobank example must load");
};
if($@) {
	fail("Rabobank example must load");
}
};
