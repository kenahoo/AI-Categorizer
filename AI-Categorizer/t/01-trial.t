# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use Test;
BEGIN { plan tests => 5 };
use AI::Categorizer;
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Learner::NaiveBayes;

ok(1);

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $k = new AI::Categorizer::KnowledgeSet
  (
   name => 'test data',
   stopwords => [qw(are be in of and)],
  );
ok($k);

use Carp; $SIG{__DIE__} = \&Carp::confess;

$k->make_document( name => 'doc1',
		   categories => ['farming'], 
		   content => 'Sheep are very valuable in farming.' );
$k->make_document( name => 'doc2',
		   categories => ['farming'],
		   content => 'Farming requires many kinds of animals.' );
$k->make_document( name => 'doc3',
		   categories => ['vampire'],
		   content => 'Vampires drink blood and may be staked.' );
$k->make_document( name => 'doc4',
		   categories => ['vampire'],
		   content => 'Vampires cannot see their images in mirrors.' );


my $nb = new AI::Categorizer::Learner::NaiveBayes
  (
   verbose => 0,
  );
ok($nb);

$nb->train(knowledge => $k);

my $doc = new AI::Categorizer::Document
  ( name => 'test1',
    content => 'I would like to begin farming sheep.' );
my $r = $nb->categorize($doc);

print "Categories: ", join(', ', $r->categories), "\n";
ok(($r->categories)[0], 'farming');

$doc = new AI::Categorizer::Document
  ( name => 'test2',
    content => "I see that many vampires may have eaten my beautiful daughter's blood." );
$r = $nb->categorize($doc);

print "Categories: ", join(', ', $r->categories), "\n";
ok(($r->categories)[0], 'vampire');

