#!/usr/bin/perl

use lib 'lib';
use AI::Categorizer;
use Carp; $SIG{__DIE__} = \&Carp::confess;

my $corpus = '../../corpora/drmath-1.00';
my $cats = read_cats("$corpus/cats.txt");

my $k = new AI::Categorizer::KnowledgeSet
  ( collection_class => 'AI::Categorizer::Collection::Files',
    document_class   => 'AI::Categorizer::Document::Text',
    path => [
	     "$corpus/test",
	     "$corpus/training",
	    ],
    #verbose => 1,
  );

my $stats = $k->scan( categories => $cats );

foreach my $stat (sort {reverse($a) cmp reverse($b)} keys %$stats) {
  print "$stat\n$stats->{$stat}\n";
}
print "\n";

my @fields = qw(document_count type_count token_count);
print join( "\t", '', @fields ), "\n";
my $cats = $stats->{categories};
foreach my $cat (sort keys %$cats) {
  print join "\t", $cat, map $cats->{$cat}{$_}, @fields;
  print "\n";
}


sub read_cats {
  my $file = shift;

  my %cats;
  open my $fh, $file or die $!;
  while (<$fh>) {
    my ($doc, @cats) = split;
    $cats{$doc} = [@cats];
  }
  return \%cats;
}
