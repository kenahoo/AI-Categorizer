#!/usr/bin/perl -w

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use strict;
use Test;
BEGIN { 
  plan tests => 10;
}

use AI::Categorizer::FeatureVector;
ok(1);

my $f1 = new AI::Categorizer::FeatureVector(features => {sports => 2, finance => 3});
ok $f1;
ok $f1->includes('sports');
ok $f1->value('sports'), 2;

my $f2 = new AI::Categorizer::FeatureVector;
ok $f2;

$f2->set({sports => 5, hockey => 7});
ok $f2->value('sports'), 5;
ok $f2->value('hockey'), 7;

my $h = $f2->as_hash;
ok keys(%$h), 2;


ok $f1->dot($f2), 10;
ok $f2->dot($f1), 10;
