# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use strict;
use Test;
BEGIN { plan tests => 19 };
use AI::Categorizer;
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Learner::NaiveBayes;

ok(1);

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

use Carp; $SIG{__DIE__} = \&Carp::confess;

my %docs = (
	    doc1 => {categories => ['farming'], 
		     content => 'Sheep are very valuable in farming.' },
	    doc2 => {categories => ['farming'],
		     content => 'Farming requires many kinds of animals.' },
	    doc3 => {categories => ['vampire'],
		     content => 'Vampires drink blood and vampires may be staked.' },
	    doc4 => {categories => ['vampire'],
		     content => 'Vampires cannot see their images in mirrors.'},
	   );

{
  my $k = new AI::Categorizer::KnowledgeSet
    (
     name => 'test data',
     stopwords => [qw(are be in of and)],
    );
  ok($k);
  
  while (my ($name, $data) = each %docs) {
    $k->make_document(name => $name, %$data);
  }

  my $nb = new AI::Categorizer::Learner::NaiveBayes
    (
     verbose => 0,
    );
  ok($nb);
  
  $nb->train(knowledge_set => $k);
  
  my $doc = new AI::Categorizer::Document
    ( name => 'test1',
      content => 'I would like to begin farming sheep.' );
  my $r = $nb->categorize($doc);
  
  print "Categories: ", join(', ', $r->categories), "\n";
  ok($r->best_category, 'farming');
  
  $doc = new AI::Categorizer::Document
    ( name => 'test2',
      content => "I see that many vampires may have eaten my beautiful daughter's blood." );
  $r = $nb->categorize($doc);
  
  print "Categories: ", join(', ', $r->categories), "\n";
  ok($r->best_category, 'vampire');
}

{
  ok my $c = new AI::Categorizer(collection_weighting => 'f');
  
  while (my ($name, $data) = each %docs) {
    $c->knowledge_set->make_document(name => $name, %$data);
  }
  
  $c->knowledge_set->finish;

  # Make sure collection_weighting is working
  ok $c->knowledge_set->document_frequency('vampires'), 2;
  for ('vampires', 'mirrors') {
    ok ($c->knowledge_set->document('doc4')->features->as_hash->{$_},
	log( keys(%docs) / $c->knowledge_set->document_frequency($_) )
       );
  }

  $c->learner->train( knowledge_set => $c->knowledge_set );
  ok $c->learner;
  
  my $doc = new AI::Categorizer::Document
    ( name => 'test1',
      content => 'I would like to begin farming sheep.' );
  ok $c->learner->categorize($doc)->best_category, 'farming';
}

{
  ok my $c = new AI::Categorizer(term_weighting => 'b');
  
  while (my ($name, $data) = each %docs) {
    $c->knowledge_set->make_document(name => $name, %$data);
  }
  
  $c->knowledge_set->finish;
  
  # Make sure term_weighting is working
  ok $c->knowledge_set->document('doc3')->features->as_hash->{vampires}, 1;
}

{
  ok my $c = new AI::Categorizer(term_weighting => 'n');
  
  while (my ($name, $data) = each %docs) {
    $c->knowledge_set->make_document(name => $name, %$data);
  }
  
  $c->knowledge_set->finish;
  
  # Make sure term_weighting is working
  ok $c->knowledge_set->document('doc3')->features->as_hash->{vampires}, 1;
  ok $c->knowledge_set->document('doc3')->features->as_hash->{blood}, 0.75;
  ok $c->knowledge_set->document('doc4')->features->as_hash->{mirrors}, 1;
}

{
  ok my $c = new AI::Categorizer(tfidf_weighting => 'txx');
  
  while (my ($name, $data) = each %docs) {
    $c->knowledge_set->make_document(name => $name, %$data);
  }
  
  $c->knowledge_set->finish;
  
  # Make sure term_weighting is working
  ok $c->knowledge_set->document('doc3')->features->as_hash->{vampires}, 2;
}
