#!/usr/bin/perl -w

use strict;
use Test;
BEGIN { plan tests => 5 };

use AI::Categorizer;
use AI::Categorizer::Document;

ok(1);

my $d = AI::Categorizer::Document->new
  (
   name => 'test',
   stopwords => ['stemming'],
   stemming => 'porter',
   content => 'stopword processing should happen before stemming',
  );
ok ref($d), 'AI::Categorizer::Document', "Test creating a Document object";

ok $d->features->includes('stopword'), 1,  "Should include 'stopword'";
ok $d->features->includes('stemming'), '', "Shouldn't include 'stemming'";
ok $d->features->includes('stem'),     '', "Shouldn't include 'stem'";
print "Features: @{[ $d->features->names ]}\n";

