package AI::Categorizer::Collection::Files;
use strict;

use AI::Categorizer::Collection;
use base qw(AI::Categorizer::Collection);

use Params::Validate qw(:types);

__PACKAGE__->valid_params
  (
   path => { type => SCALAR|ARRAYREF },
   categories => { type => HASHREF, default => {} },
  );

__PACKAGE__->contained_objects
  (
   document => { class => 'AI::Categorizer::Document::Text',
		 delayed => 1 },
  );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  
  $self->{dir_fh} = do {local *FH; *FH};  # double *FH avoids a warning

  # Documents are contained in a directory, or list of directories
  $self->{path} = [$self->{path}] unless ref $self->{path};

  $self->_next_path;
  return $self;
}

sub _next_path {
  my $self = shift;
  closedir $self->{dir_fh} if $self->{cur_dir};

  $self->{cur_dir} = shift @{$self->{path}};
  opendir $self->{dir_fh}, $self->{cur_dir} or die "$self->{cur_dir}: $!";
}

sub next {
  my $self = shift;

  my $file = readdir $self->{dir_fh};
  if (!defined $file) { # Directory has been exhausted
    return undef unless @{$self->{path}};
    $self->_next_path;
    return $self->next;
  } elsif ($file eq '.' or $file eq '..') {
    return $self->next;  # Skip
  } elsif (-d "$self->{cur_dir}/$file") {
    push @{$self->{path}}, "$self->{cur_dir}/$file";  # Add for later processing
    return $self->next;
  }

  my $k = $self->container;
  my @cats = map $k->category_by_name($_), @{ $self->{categories}{$file} || [] };

  return $self->call_method('document', 'read', 
			    path => "$self->{cur_dir}/$file",
			    categories => \@cats,
			   );
}

1;
