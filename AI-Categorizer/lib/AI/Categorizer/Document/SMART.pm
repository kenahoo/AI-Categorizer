package AI::Categorizer::Document::SMART;

use strict;
use AI::Categorizer::Document;
use base qw(AI::Categorizer::Document);

#use Params::Validate qw(:types);
#use AI::Categorizer::ObjectSet;
#use AI::Categorizer::FeatureVector;

### Constructors

sub read {
  my ($class, %args) = @_;
  my $path = delete $args{path} or die "Must specify 'path' argument to read()";
  $args{name} ||= $path;

  local *FH;
  open FH, "< $path" or die "$path: $!";
  my $text = do {local $/; <FH>};
  close FH;

  my ($content, $categories) = $class->parse($text);
  return $class->SUPER::new(%args, content => $content, categories => $categories);
}

sub parse {
  my ($self, $text) = @_;
  
  $text =~ s{
	     ^(?:\.I)?\s+(\d+)\n  # ID number - becomes document name
	     \.C\n
	     ([^\n]+)\n     # Categories
	     \.T\n
	     (.+)\n+        # Title
	     \.W\n
	    }
            {}sx
     
     or die "Malformed record: $text";
  
  my ($id, $categories, $title) = ($1, $2, $3);
  s/\.I$//;

  my @categories = $categories =~ m/(.*?)\s+1[\s;]*/g;
  #print "found $id => (@categories)\n";

  return { name => $id, title => $title, body => $text }, \@categories;
}

  
  
}

1;
