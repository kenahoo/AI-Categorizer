# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use AI::Categorizer;
use AI::Categorizer::KnowledgeSet;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $k = new AI::Categorizer::KnowledgeSet( name => 'test data',
					   stopwords => [qw(are be in of and)],
					 );
ok($k);

#use Carp; $SIG{__DIE__} = \&Carp::confess;

$k->make_document( name => 'doc1',
		   categories => ['farming'], 
		   body => 'Sheep are very valuable in farming.' );
$k->make_document( name => 'doc2',
		   categories => ['farming'],
		   body => 'Farming requires many kinds of animals.' );
$k->make_document( name => 'doc3',
		   categories => ['vampire'],
		   body => 'Vampires drink blood and may be staked.' );
$k->make_document( name => 'doc4',
		   categories => ['vampire'],
		   body => 'Vampires cannot see their images in mirrors.' );

__END__

my $r = $c->categorize('I would like to begin farming sheep.');
print "Categories: ", join(', ', $r->categories), "\n";
&report_result(($r->categories)[0] eq 'farming');

$r = $c->categorize("I see that many vampires may have eaten my beautiful daughter's blood.");
print "Categories: ", join(', ', $r->categories), "\n";
&report_result(($r->categories)[0] eq 'vampire');
