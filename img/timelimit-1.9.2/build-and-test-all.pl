#!/usr/bin/perl
#
# Copyright (c) 2018  Peter Pentchev
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

use v5.10;
use strict;
use warnings;

sub announce($) {
	say "\n\n========= $_[0]\n";
}

sub check_cmd(@) {
	my (@cmd) = @_;

	say "Running '@cmd'";
	system { $cmd[0] } @cmd;
	my $status = $?;
	die "'@cmd' exited with code $status\n" unless $status == 0;
}

sub run($ $ $)
{
	my ($ac, $defined, $undefined) = @_;

	announce "Testing defined (@{$defined}) undefined (@{$undefined})";

	open my $f, '>', $ac or
	    die "Could not open $ac for writing: $!\n";
	for my $var (@{$defined}) {
		say $f "#define $var" or
		    die "Could not write to $ac: $!\n";
	}
	for my $var (@{$undefined}) {
		say $f "#undef $var" or
		    die "Could not write to $ac: $!\n";
	}
	close $f or
	    die "Could not close $ac after writing: $!\n";
	check_cmd 'cat', '--', $ac;
	check_cmd 'rm', '-f', '--', 'timelimit.o', 'timelimit';
	check_cmd 'make', 'check';
}

sub toggle_run($ $ $ $);
sub toggle_run($ $ $ $)
{
	my ($ac, $predefined, $defined, $undefined) = @_;

	if (!@{$defined}) {
		run $ac, $predefined, $undefined;
		return;
	}

	my ($symbol, @rest) = @{$defined};
	toggle_run $ac, $predefined, \@rest, [@{$undefined}, $symbol];
	toggle_run $ac, [@{$predefined}, $symbol], \@rest, $undefined;
}

MAIN:
{
	my $ac = 'autoconfig.h';

	announce 'Cleaning up at the start';
	check_cmd qw(make clean);
	if (-e $ac) {
		say "Removing '$ac'";
		unlink $ac or
		    die "Could not remove $ac: $!\n";
	}

	announce "Generating '$ac'";
	check_cmd ('make', '--', $ac);
	if (! -f $ac) {
		die "'make $ac' did not generate '$ac'\n";
	}

	my (@defined, @undefined);
	open my $f, '<', $ac or
	    die "Could not open '$ac' for reading: $!\n";
	while (my $line = <$f>) {
		chomp $line;
		if ($line =~ m{^ \s*
			[#] \s* define \s+
			(?<sym> [A-Za-z0-9_]+ ) \s*
		$}x) {
			push @defined, $+{sym};
		} elsif ($line =~ m{^ \s*
			[#] \s* undef \s+
			(?<sym> [A-Za-z0-9_]+ ) \s*
		$}x) {
			push @undefined, $+{sym};
		} else {
			die "Unexpected line in $ac: $line\n";
		}
	}
	close $f or
	    die "Could not close '$ac' after reading: $!\n";
	say "Defined symbols: @defined";
	say "Undefined symbols: @undefined";

	# Gah, errno may be defined as thread-local, so we cannot
	# really work around it, can we...
	my $errno = 'HAVE_ERRNO_H';
	my @predefined = grep $_ eq $errno, @defined;
	my @defined = grep $_ ne $errno, @defined;
	if (@predefined) {
		say "After the $errno fixup, only testing: @defined";
	}

	if (!@defined) {
		say 'No tests to run!';
		exit(0);
	}
	say 'About to run '.(1 << scalar @defined).' tests';
	toggle_run $ac, \@predefined, \@defined, \@undefined;
}
