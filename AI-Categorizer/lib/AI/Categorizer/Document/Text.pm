package AI::Categorizer::Document::Text;

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
  my $body = do {local $/; <FH>};
  close FH;
  
  return $class->SUPER::new(%args, content => $body);
}

1;
