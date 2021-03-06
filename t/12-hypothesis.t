#!/usr/bin/perl -w

use strict;
use Test;
BEGIN { 
  plan tests => 8;
};

use AI::Categorizer::Hypothesis;
ok(1);

my @cats = ('a'..'z', 'foo', 'bar');

my $h = new AI::Categorizer::Hypothesis
  (
   all_categories => \@cats,
   scores => {
	      a => 0.162625189870596,
	      b => 0.196310929488391,
	      c => 0.342389536555856,
	      d => 0.992922217119485,
	      e => 0.647070572711527,
	      f => 0.769043266773224,
	      g => 0.0594661883078516,
	      h => 0.119586664251983,
	      i => 0.535241201054305,
	      j => 0.673286426346749,
	      k => 0.610552420839667,
	      l => 0.933217488694936,
	      m => 0.989309431985021,
	      n => 0.140130351763219,
	      o => 0.062918059527874,
	      p => 0.825955434702337,
	      q => 0.963266535662115,
	      r => 0.37753611523658,
	      s => 0.769046582747251,
	      t => 0.495079542975873,
	      u => 0.0292209032922983,
	      v => 0.323792772833258,
	      w => 0.959334740880877,
	      x => 0.561960874125361,
	      y => 0.0025778217241168,
	      z => 0.760564740281552,
	     },
   threshold => 0.95,
   document_name => 'foo',
  );
ok $h;

ok $h->categories, 4;
ok $h->best_category, 'd',
ok $h->in_category('d');
ok $h->in_category('m');
ok !$h->in_category('j');
ok !$h->in_category('foo');
