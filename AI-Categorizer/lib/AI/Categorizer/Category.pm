package AI::Categorizer::Category;

use strict;
use Class::Container;
use base qw(Class::Container);
use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   name => {type => SCALAR, public => 0},
   documents  => {
		  type => ARRAYREF,
		  default => [],
		  callbacks => { 'all are Document objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Categorizer::Document'), @_ },
			       },
		  public => 0,
		 },
  );

__PACKAGE__->make_accessors(':all');

sub new {
  my $self = shift()->SUPER::new(@_);
  $self->{document_hash} = map {$_->name => 1} @{$self->documents};
  return $self;
}

sub contains_document {
  return $_[0]->{document_hash}{ $_[1]->name };
}

sub add_document {
  my $self = shift;
  push @{$self->{documents}}, $_[0];
}

1;
