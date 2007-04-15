package AI::Categorizer::Document::ScoredFeatures;

use strict;
use AI::Categorizer::Document;
use base qw(AI::Categorizer::Document);

sub create_feature_vector {
  my ($self) = @_;
  $self->{features} = $self->create_delayed_object('features', features => $self->{content});
}

sub parse {
  my ($self, %args) = @_;
  die "No 'content' argument given to parse()" unless exists $args{content};
  
  local $_;
  my ($i, %features) = (1);
  while (($_) = $args{content} =~ m/(.*)/mg) {
    chomp;
    /^(.*)\t(.+)$/ or die "Bad data at line $.: $_";
    $features{$1} = $2;
    $i++;
  }

  $self->{content} = \%features;
}

sub parse_handle {
  my ($self, %args) = @_;
  my $fh = $args{handle} or die "No 'handle' argument given to parse_handle()";
  
  my %features;
  while (<$fh>) {
    chomp;
    /^(.*)\t(.+)$/ or die "Bad data at line $.: $_";
    $features{$1} = $2;
  }
  
  $self->{content} = \%features;
}

1;
