package SWIFT::MT940;
use strict;
use warnings;

our $VERSION = "1.0";

=head1 NAME

SWIFT::MT940 - Read Structured MT940 SWIFT files

=head1 SYNOPSIS

 #!/usr/bin/perl
 use strict;
 use warnings;
 use SWIFT::MT940;
 use Data::Dumper;
 
 my $mt940_contents = `cat ...`; # or some other way
 
 eval {
   my $mt940 = SWIFT::MT940->parse($mt940_contents);
   print Dumper([$mt940->get_statements()]);
   print Dumper([$mt940->get_transactions()]);
 };
 if($@) {
   warn "Read failed: " . Dumper($@);
   exit;
 }

=head1 DESCRIPTION

This is a module to read Structured MT940 SWIFT files. It is tested against
the Rabobank format documented at:

 https://www.rabobank.com/en/float/fl/downloads.html

Some banks may use similar formats; if you want to add support for them,
patches are welcome.

=head2 Methods

=cut

sub raise {
	my ($message) = @_;
	my ($package, $filename, $line) = caller;
	my $stacktrace = [];
	my $i = 1;
	while(my @stack = caller($i++)) {
		push @$stacktrace, \@stack;
	}
	my $error = {
		what => $message,
		package => $package,
		filename => $filename,
		line => $line,
		stacktrace => $stacktrace,
	};
	die $error;
}

sub assert {
	my ($cond) = @_;
	if(!$cond) {
		raise("Assertion failed");
	}
}

=head3 SWIFT::MT940->parse($data)

Parses the given data, which is a complete MT940 document. Returns a
SWIFT::MT940 object.

=cut

sub parse {
	my ($pkg, $data) = @_;
	my $self = {};
	bless $self, $pkg;
	$self->{'body'} = $data;
	$self->{'offset'} = 0;
	$self->{'statements'} = [];
	
	$self->read_magic();
	while(my $next = $self->peek_block()) {
		if($next eq "20") {
			push @{$self->{statements}}, $self->read_statement();
		} else {
			raise("Unknown tag in global scope: $next\n");
			last;
		}
	}
	return $self;
}

=head3 $mt940->get_statements()

Returns an array of statements in the data given to parse().

=cut

sub get_statements {
	my ($self) = @_;
	return @{$self->{statements}};
}

=head3 $mt940->get_transactions()

Returns an array of transactions in the data given to parse(). This is simply
implemented as:

  return (map { @{$_->{transactions}} } $self->get_statements());

=cut

sub get_transactions {
	my ($self) = @_;
	return (map { @{$_->{transactions}} } $self->get_statements());
}

=head1 AUTHOR

Sjors Gielen <sjors@limesco.org>

=head1 LICENSE

 Copyright (c) 2013, Sjors Gielen
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the <organization> nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

### Internal

sub read_magic {
	my ($self) = @_;
	# MT940 magic is ":940:"
	my @magic;
	push @magic, $self->read_block() for(1..3);
	if(!defined($magic[0]) || $magic[0] ne "") {
		raise("MT940 magic is not :940:");
	} elsif(!defined($magic[1]) || $magic[1] ne "940") {
		raise("MT940 magic is not :940:");
	} elsif(!defined($magic[2]) || $magic[2] ne "") {
		raise("MT940 magic is not :940:");
	}
}

sub read_statement {
	my ($self) = @_;

	my $statement = {transactions => []};

	# Statement starts with tag 20, ends with the next tag 20 or at EOF
	my $st_start = $self->read_block();
	if($st_start != "20") {
		raise("Statement did not start with :20: tag.");
	}
	$statement->{id} = $self->read_block();
	while(my $tag = $self->peek_block()) {
		if($tag eq "20") {
			# Next statement starts after this
			return $statement;
		} elsif($tag eq "61") {
			# Nested transaction
			push @{$statement->{transactions}}, $self->read_transaction();
			next;
		}

		# (assert must not be compiled away here, read_block changes state)
		assert($tag eq $self->read_block());

		if($tag eq "21") {
			$statement->{related} ||= [];
			push @{$statement->{related}}, $self->read_block();
		} elsif($tag eq "25") {
			$statement->{account} = $self->read_block();
		} elsif($tag eq "28C") {
			$statement->{serial} = $self->read_block();
		} elsif($tag eq "60F") {
			$statement->{previous_balance} = $self->read_block();
		} elsif($tag eq "62F") {
			$statement->{balance} = $self->read_block();
		} elsif($tag eq "64") {
			$statement->{valuta_balance} = $self->read_block();
		} elsif($tag eq "65") {
			$statement->{next_valuta_balance} ||= [];
			push @{$statement->{next_valuta_balance}}, $self->read_block();
		} else {
			raise("Unknown tag in statement scope: $tag\n");
		}
	}
	# EOF reached
	return $statement;
}

sub read_transaction {
	my ($self) = @_;
	my $transaction = {};
	# Transaction starts with tag 61, ends with next tag 61, next tag 20, or at EOF
	my $tr_start = $self->read_block();
	if($tr_start != "61") {
		raise("Transaction did not start with :61: tag.");
	}
	$transaction->{id} = $self->read_block();
	# 121001C000000000082,33N122NONREF
	# 0159134706
	if($transaction->{id} =~ /^(\d\d)(\d\d)(\d\d)(\d{2}?)(\d{2}?)(R?)(D|C)(\d+[,.]\d+)N(\w\w\w)(MARF|EREF|PREF|NONREF)(.*)$/s) {
		my ($year, $month, $day, $bookmonth, $bookday, $reverse, $debetcredit, $amount, $type, $ref, $extra)
		    = ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11);
		$amount =~ s/,/./;
		$amount += 0; # re-interpret as number
		$transaction->{date} = "20$year-$month-$day";
		$transaction->{bookdate} = "20$year-$month-$day";
		$transaction->{reverse} = $reverse eq "R";
		$transaction->{debetcredit} = $debetcredit;
		$transaction->{amount} = $amount;
		$transaction->{type} = $type;
		$transaction->{ref} = $ref;
		$transaction->{extra} = $extra;
	}
	while(my $tag = $self->peek_block()) {
		if($tag ne "86") {
			# Next statement or transaction starts after this
			return $transaction;
		}

		assert($tag eq $self->read_block());
		if($tag eq "86") {
			$transaction->{information} = $self->read_block();
		} else {
			raise("Unknown tag in transaction scope: $tag\n");
		}
	}
	# EOF reached
	return $transaction;
}

sub peek_block {
	my ($self) = @_;
	return $self->read_block(1);
}

# Read until the next colon (:). Surrounding newlines, which had been added for
# readability, are removed. The value of the block is returned. undef is
# returned if there was nothing to read. Before and after returning, "offset"
# points at the first character of a new group. If $peek is given and true, the
# function does not change the offset.
sub read_block {
	use bytes;
	my ($self, $peek) = @_;
	$peek ||= 0;

	my $l = length($self->{body});
	my $o = $self->{offset};
	if($o == $l) {
		# string ends with colon, or string is empty
		# that makes for one last valid block
		$self->{offset} = $o + 1 unless $peek;
		return "";
	} elsif($o > $l) {
		# we've already read beyond end of string
		return undef;
	}

	my $block = "";
	while(1) {
		my $c = substr($self->{body}, $o, 1);
		$o++;
		if($c eq ':') {
			$self->{offset} = $o unless $peek;
			return trim($block);
		}
		$block .= $c;
		if($l == $o) {
			# EOF reached inside a block; next call will be beyond
			# end of string
			$self->{offset} = $o + 1 unless $peek;
			return trim($block);
		}
	}
}

sub trim {
	local $_ = pop;
	s/^\n+//; s/\n+$//;
	return $_;
}

1;
