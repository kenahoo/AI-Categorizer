#!/usr/bin/perl

# This script isn't an officially supported interface, but it may be
# useful.  It creates a Categorizer and runs several of its method on
# a corpus, reporting the results.
#
# Copyright 2002 Ken Williams, under the same license as the
# AI::Categorizer distribution.

use strict;
use AI::Categorizer;

my (%opt, %do_stage);
parse_command_line(@ARGV);
@ARGV = grep !/^-\d$/, @ARGV;

my $c = new AI::Categorizer(%opt);

%do_stage = map {$_, 1} 1..5 unless keys %do_stage;

run_section('scan_features',     1, \%do_stage);
run_section('read_training_set', 2, \%do_stage);
run_section('train',             3, \%do_stage);
run_section('evaluate_test_set', 4, \%do_stage);
if ($do_stage{5}) {
  my $result = $c->stats_table;
  print $result;
  if ( my $file = $c->progress_file ) {
    local *FH;
    open FH, "> $file-results.txt" or die "$file-results.txt: $!";
    # Should also dump parameters here
    print FH $result;
    close FH;
  }
}

sub run_section {
  my ($section, $stage, $do_stage) = @_;
  return unless $do_stage->{$stage};
  if (keys %$do_stage > 1) {
    print " % $0 @ARGV -$stage\n";
    system($0, @ARGV, "-$stage") == 0
      or die "$0 returned nonzero status, \$?=$?";
    return;
  }
  return $c->$section();
}

sub parse_command_line {

  while (@_) {
    if ($_[0] =~ /^-(\d+)$/) {
      shift;
      $do_stage{$1} = 1;
      
    } elsif ( $_[0] eq '--config_file' ) {
      shift;
      my $file = shift;
      eval {require YAML; 1}
	or die "--config_file requires the YAML Perl module to be installed.\n";
      my $href = YAML::LoadFile($file);
      @opt{keys %$href} = values %$href;
      
    } elsif ( $_[0] =~ /^--/ ) {
      my ($k, $v) = (shift, shift);
      $k =~ s/^--//;
      $opt{$k} = $v;
      
    } else {
      die "Unknown option format '$_[0]'.  Do you mean '--$_[0]'?\n";
    }
  }

  while (my ($k, $v) = each %opt) {
    # Allow abbreviations
    if ($k =~ /^(\w+)_class$/) {
      my $name = $1;
      $v =~ s/^::/AI::Categorizer::\u${name}::/;
      $opt{$k} = $v;
    }
  }
}
