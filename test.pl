#!/bin/perl

use warnings;
use strict;
use lib `pwd`;
use Data::Dumper;
use Analyzer;
use DBI;

use LWP::Simple qw();

$| = 1;

my $passwort = `cat passwort.txt`;
chomp($passwort);

sub testThis { 
	return $_[0] if $_[0] eq "DBI";
	return "test-db";
}
my $sr = 0 ? \&testThis : undef;	# erstellt eine Funktionsreferenz (wenn vorne 1 steht),
					# die auf jedes Element der Parameter angewendet wird.
					# Achtung: Auch $self (bei objektorientierten Methoden)
					# ist hier. Um das "Ignorieren" bzw. holen von $self
					# muss sich der Autor dieser Methode kümmern

my $analyzer = Analyzer->new("DBI", "connect", 0, 1, $sr);
$analyzer->heal();		# temporär die Originalmethode wiederherstellen
$analyzer->reinject();		# Wieder die Debugging-Methode einschalten


my $dbh = DBI->connect("DBI:mysql:host=localhost", "root", $passwort);


my $analyzer2 = Analyzer->new(ref($dbh), "selectall_hashref", 1, 1, $sr);
my $query = "select * from stundenerfassung.user";
my @data = $dbh->selectall_hashref($query, "id");


print "\n";


my $avg_laufzeit = $analyzer->getAvgTime();
my $avg_laufzeit2 = $analyzer2->getAvgTime();
print "Durchschnittliche Laufzeit der DBH::connect-Methode:             $avg_laufzeit\n";
print "Durchschnittliche Laufzeit der DBH::db::selectrow_array-Methode: $avg_laufzeit2\n";


my $avg_elements = $analyzer->getAvgElements();
my $avg_elements2 = $analyzer2->getAvgElements();
print "Durchschnittliche Anzahl der returnten Objekte bei DBI::Connect:             $avg_elements\n";
print "Durchschnittliche Anzahl der returnten Objekte bei DBI::db::selectrow_array: $avg_elements2\n";



#my $analyzer3 = Analyzer->new("Encode", "encode");
#Encode::encode("iso-8859-1", "hallo");
