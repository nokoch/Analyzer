#!/bin/perl

use warnings;
use strict;
use lib `pwd`;
use Analyzer;
use DBI;

$| = 1;

my $passwort = `cat passwort.txt`;
chomp($passwort);

sub testThis { 
	return $_[0] if $_[0] eq "DBI";
	return "test-db";
}

my $sr =	0
		? \&testThis : undef;

my $analyzer = Analyzer->new("DBI", "connect", 0, 1, $sr);
$analyzer->heal();		# temporär die Originalmethode wiederherstellen
$analyzer->reinject();		# Wieder die Debugging-Methode einschalten

my $dbh = DBI->connect("DBI:mysql:host=localhost", "root", $passwort);

my $analyzer2 = Analyzer->new(ref($dbh), "selectrow_array", 1, 1, $sr);
my $query = "select * from information_schema.tables";
my @data = $dbh->selectrow_array($query);
