# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use strict;
use Test;
BEGIN {
  require 't/common.pl';
  need_module('AI::DecisionTree 0.05');
  plan tests => 5;
}

use AI::Categorizer;
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Learner::DecisionTree;

ok(1);

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

use Carp; $SIG{__DIE__} = \&Carp::confess;

my %docs = test_docs();
{
  my $k = new AI::Categorizer::KnowledgeSet
    (
     name => 'Vampires/Farmers',
     stopwords => [qw(are be in of and)],
    );
  ok($k);
  
  while (my ($name, $data) = each %docs) {
    $k->make_document(name => $name, %$data);
  }

  my $l = new AI::Categorizer::Learner::DecisionTree(verbose => 0);
  ok($l);
  
  $l->train(knowledge_set => $k);
  
  my $doc = new AI::Categorizer::Document
    ( name => 'test1',
      content => 'I would like to begin farming sheep.' );
  my $r = $l->categorize($doc);
  
  print "Categories: ", join(', ', $r->categories), "\n";
  ok($r->best_category, 'farming');
  
  $doc = new AI::Categorizer::Document
    ( name => 'test2',
      content => "I see that many vampires may have eaten my beautiful daughter's blood." );
  $r = $l->categorize($doc);
  
  print "Categories: ", join(', ', $r->categories), "\n";
  ok($r->best_category, 'vampire');
}
