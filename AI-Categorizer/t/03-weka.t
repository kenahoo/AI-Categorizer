#!/usr/bin/perl -w

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use strict;
use Test;
BEGIN {
  require 't/common.pl';
  skip_test("Weka is not installed") unless -e "classpath";
  plan tests => 1 + num_standard_tests();
}

ok(1);

#########################

my @args;
local *FH;
open FH, "classpath" or die "Can't open classpath: $!";
my $line = <FH>;
push @args, weka_path => $line
  unless $line eq '-';

perform_standard_tests(
		       learner_class => 'AI::Categorizer::Learner::Weka',
		       weka_classifier => 'weka.classifiers.SMO',
		       @args,
		      );

