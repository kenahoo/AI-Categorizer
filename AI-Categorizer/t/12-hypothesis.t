#!/usr/bin/perl -w

use strict;
use Test;
BEGIN { 
  plan tests => 8;
};

use AI::Categorizer::Hypothesis;
ok(1);

my @cats = ('a'..'z');

my $h = new AI::Categorizer::Hypothesis
  (
   all_categories => \@cats,
   scores => {a => 0.5, b => 0.6, c => -0.1},
   threshold => 0.3,
   document_name => 'foo',
  );
ok $h;

ok $h->categories, 2;
ok $h->best_category, 'b',
ok $h->in_category('a');
ok $h->in_category('b');
ok !$h->in_category('c');
ok !$h->in_category('d');
