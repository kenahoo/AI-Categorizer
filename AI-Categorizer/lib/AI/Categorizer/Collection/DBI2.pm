package AI::Categorizer::Collection::DBI2;
use strict;

use DBI;
use AI::Categorizer::Collection;
use AI::Categorizer::Category;
use base qw(AI::Categorizer::Collection);

use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   connection_string => {type => SCALAR, default => undef},
   dbh => {isa => 'DBI::db', default => undef},
   select_statement => {type => SCALAR, default => "SELECT text FROM documents"},
  );

__PACKAGE__->contained_objects
  (
   document => { class => 'AI::Categorizer::Document',
		 delayed => 1 },
  );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  
  die "Must provide 'dbh' or 'connection_string' arguments"
    unless $self->{dbh} or $self->{connection_string};
  
  unless ($self->{dbh}) {
    $self->{dbh} = DBI->connect($self->{connection_string}, '', '', {RaiseError => 1})
      or die DBI->errstr;
    delete $self->{connection_string};
  }
  
  $self->rewind;
  return $self;
}

sub dbh { shift()->{dbh} }

sub rewind {
  my $self = shift;
  
  if (!$self->{sth}) {
    $self->{sth} = $self->dbh->prepare($self->{select_statement});
  }

  if ($self->{sth}{Active}) {
    $self->{sth}->finish;
  }

  $self->{sth}->execute;
}

sub next {
  my $self = shift;

  my @result = $self->{sth}->fetchrow_array;
  return undef unless @result;
  my @cats=(new AI::Categorizer::Category(name=>$result[1]));
  return $self->create_delayed_object('document',
				      name => $result[0],
				      categories => \@cats,	
				      content => $result[2],
				     );
}

1;
