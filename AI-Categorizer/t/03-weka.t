# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use strict;
use Test;
BEGIN {
  require 't/common.pl';
  skip_test("Weka is not installed") unless -e "t/classpath";
  plan tests => 5;
}
use AI::Categorizer;
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Learner::Weka;

ok(1);

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

use Carp; $SIG{__DIE__} = \&Carp::confess;

my %docs = training_docs();
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

  my @args;
  
  local *FH;
  open FH, "t/classpath" or die "Can't open t/classpath: $!";
  my $line = <FH>;
  push @args, weka_path => $line
    unless $line eq '-';

  my $l = new AI::Categorizer::Learner::Weka
    (
     verbose => 0,
     @args,
    );
  ok($l);

  $l->train(knowledge_set => $k);

  run_test_docs($l);
}
