# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use strict;
use Test;
BEGIN { plan tests => 17, todo => [15, 16, 17] };

use AI::Categorizer;
use AI::Categorizer::Experiment;
use AI::Categorizer::Hypothesis;

ok(1);

my $h = new AI::Categorizer::Hypothesis
  (
   scores => {
	      sports => 7,
	      politics => 3,
	      finance => 5,
	     },
   threshold => 4,
  );

ok $h->best_category, 'sports';
ok scalar $h->categories, 2;
ok $h->scores('finance'), 5;

{
  my $e = new AI::Categorizer::Experiment;
  ok $e;
  
  $e->add_hypothesis($h, ['sports']);
  ok $e->macro_recall, 1, "macro recall";
  ok $e->macro_precision, 0.5, "macro precision";
  ok $e->macro_F1, 2/3, "macro F1";
}

{
  my $e = new AI::Categorizer::Experiment;
  $e->add_hypothesis($h, ['politics']);
  ok $e->macro_recall, 0, "macro recall";
  ok $e->macro_precision, 0, "macro precision";
  ok $e->macro_F1, 0, "macro F1";
}

{
  my $e = new AI::Categorizer::Experiment;
  
  $e->add_hypothesis($h, ['sports']);
  $e->add_hypothesis($h, ['politics']);

  ok $e->macro_recall, 0.5, "macro recall";
  ok $e->macro_precision, 0.25, "macro precision";
  ok $e->macro_F1, 1/3, "macro F1";

  ok $e->micro_recall, 0.5, "macro recall";
  ok $e->micro_precision, 0.25, "macro precision";
  ok $e->micro_F1, 1/3, "macro F1";
}
