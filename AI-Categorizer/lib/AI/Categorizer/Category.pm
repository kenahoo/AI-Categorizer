package AI::Classifier::Category;

use strict;
use Class::Container;
use base qw(Class::Container);
use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   name => {type => SCALAR},
   documents  => {
		  type => ARRAYREF,
		  callbacks => { 'all are Document objects' => 
				 sub { ! grep !UNIVERSAL::isa($_, 'AI::Classifier::Document'), @_ },
			       },
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

1;
