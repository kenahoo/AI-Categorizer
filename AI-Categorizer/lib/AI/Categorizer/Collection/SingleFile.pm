package AI::Categorizer::Collection::SingleFile;
use strict;

use AI::Categorizer::Collection;
use base qw(AI::Categorizer::Collection);

use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   path => { type => SCALAR|ARRAYREF },
   categories => { type => HASHREF|UNDEF, default => undef },
   delimiter => { type => SCALAR },
  );

__PACKAGE__->contained_objects
  (
   document => { class => 'AI::Categorizer::Document::Text',
		 delayed => 1 },
  );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  
  $self->{fh} = do {local *FH; *FH};  # double *FH avoids a warning

  # Documents are contained in a file, or list of files
  $self->{path} = [$self->{path}] unless ref $self->{path};

  $self->_next_path;
  return $self;
}

sub _next_path {
  my $self = shift;
  close $self->{fh} if $self->{cur_file};

  $self->{cur_file} = shift @{$self->{path}};
  open $self->{fh}, "< $self->{cur_file}" or die "$self->{cur_file}: $!";
}

sub next {
  my $self = shift;

  my $fh = $self->{fh}; # Must put in a simple scalar
  my $content = do {local $/ = $self->{delimiter}; <$fh>};

  if (!defined $content) { # File has been exhausted
    return undef unless @{$self->{path}};
    $self->_next_path;
    return $self->next;
  }

  my ($doc, $categories) = $self->call_method('document', 'parse', 
					      text => $content,
					     );
  my $k = $self->container;
  my @categories = map $k->category_by_name($_) @$categories;
  return $k->create_contained_object('document', content => $doc, categories => \@categories);
}

1;
