#!/usr/bin/perl

use lib 'lib';
use AI::Categorizer;
use Carp; $SIG{__DIE__} = \&Carp::confess;

my @corpora = (
#	       {
#		name => 'drmath-1.00',
#		path => ['../../corpora/drmath-1.00/test',
#			 '../../corpora/drmath-1.00/training'],
#		document_class   => 'AI::Categorizer::Document::Text',
#		collection_class => 'AI::Categorizer::Collection::Files',
#		categories => '../../corpora/drmath-1.00/cats.txt',
#	       },
	       
#	       {
#		name => 'signalg',
#		path => ['../../corpora/signalg/doc.smart',
#			 '../../corpora/signalg/query.smart'],
#		document_class   => 'AI::Categorizer::Document::SMART',
#		collection_class => 'AI::Categorizer::Collection::SingleFile',
#		delimiter => "\n.I",
#	       },
	       
	       {
		name => 'aptemod',
		path => ['../../corpora/reuters-21578/test',
			 '../../corpora/reuters-21578/training'],
		document_class   => 'AI::Categorizer::Document::Text',
		collection_class => 'AI::Categorizer::Collection::Files',
		categories => '../../corpora/reuters-21578/cats.txt',
	       },
	      );

foreach my $corpus (@corpora) {
  print delete $corpus->{name}, "\n";

  my %args;
  if ($corpus->{categories}) {
    $args{categories} = read_cats(delete $corpus->{categories});
  }

  my $k = new AI::Categorizer::KnowledgeSet
    ( %$corpus,
      verbose => 1,
    );

  my $stats = $k->scan(%args, document_class => $corpus->{document_class} );

  foreach my $stat (sort {reverse($a) cmp reverse($b)} keys %$stats) {
    print "$stat\t$stats->{$stat}\n";
  }
  print "\n";

  my @fields = qw(document_count type_count token_count);
  print join( "\t", '', @fields ), "\n";
  my $cats = $stats->{categories};
  foreach my $cat (sort keys %$cats) {
    print join "\t", $cat, map $cats->{$cat}{$_}, @fields;
    print "\n";
  }
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
