#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 9;

BEGIN { use_ok("SWIFT::MT940"); }

SKIP: {
	eval {
		my $obj = SWIFT::MT940->parse(":940:");
		pass("Valid empty statement list must load");
		is($obj->get_statements(), 0, "Valid empty statement list must have no statements");
		is($obj->get_transactions(), 0, "Valid empty transactions list must have no transactions");
	};
	if($@) {
		fail("Valid empty statement list must load");
		skip "No results", 2;
	}
}

sub invalid_test {
	my $name = "Invalid file " . $_[0] . " should generate error";
	eval {
		SWIFT::MT940->parse($_[1]);
		fail($name);
	};
	if($@) {
		pass($name);
	}
}

my @invalid_files = (
	"",
	":",
	"::940:",
	":123:",
	"940:",
);
for(my $i = 0; $i < @invalid_files; ++$i) {
	invalid_test($i, $invalid_files[$i]);
}
