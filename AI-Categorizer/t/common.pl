
use strict;
use Test;

sub have_module {
  my $module = shift;
  return eval "use $module; 1";
}

sub need_module {
  my $module = shift;
  skip_test("$module not installed") unless have_module($module);
}

sub skip_test {
  my $msg = @_ ? shift() : '';
  print "1..0 # Skipped: $msg\n";
  exit;
}

sub training_docs {
  return (
	  doc1 => {categories => ['farming'],
		   content => 'Sheep are very valuable in farming.' },
	  doc2 => {categories => ['farming'],
		   content => 'Farming requires many kinds of animals.' },
	  doc3 => {categories => ['vampire'],
		   content => 'Vampires drink blood and vampires may be staked.' },
	  doc4 => {categories => ['vampire'],
		   content => 'Vampires cannot see their images in mirrors.'},
	 );
}

sub run_test_docs {
  my $l = shift;

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
1;
