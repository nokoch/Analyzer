package Analyzer;
use warnings;
use strict;

use Time::HiRes qw(gettimeofday);

my %oldCode = ();
my %optionen = ();

=begin nd
new erstellt ein neues Analyzer-Objekt. Folgende Parameter können übergeben werden (in dieser Reihenfolge):
Package (String)
Name der Sub (String)
Ob Daten angezeigt werden sollen (1 oder 0)
Ob die Funktion wirklich ausgeführt werden soll (1 oder 0)
Eine Funktionsreferenz, die für jeden Parameter ausgeführt werden soll (Coderef)
=cut

sub new {
	my $self = shift;

	my ($subPackage, $subName, $showData, $reallyExecute, $subRef) = @_;
	if($subPackage eq "CORE") {
		warn "Die CORE-Modul-Methoden zu ersetzen, kann gefährlich sein und zu Endlosschleifen führen!\n";
	}
	if($subPackage && $subName) {
		$optionen{subPackage} = $subPackage;
		$optionen{subName} = $subName;
		_injectCode($self, $subPackage, $subName);
	} else {
		die "Nicht genügend Parameter";
	}

	if(ref $subRef eq "CODE") {
		$optionen{subRefs}{$subPackage}{$subName} = \&$subRef;
	}

	$optionen{showData}{$subPackage}{$subName} = (defined($showData) ? $showData : 1);
	$optionen{reallyExecute}{$subPackage}{$subName} = (defined($reallyExecute) ? !!$reallyExecute : 1);

	return bless(\%optionen, $self);
}

=begin nd
_injectCode "injiziert" den Code und überschreibt den Code der Originalmodule.
Parameter:
subPackage (String)
subName (String)

Diese Funktion sollte nur von innerhalb des Moduls aufgerufen werden. Alles weitere wird von außen über new geregelt.
=cut
sub _injectCode {
	my $self = shift;
	my $subPackage = shift;
	my $subName = shift;

	no strict 'refs';
	no warnings 'redefine';
	no warnings 'uninitialized';
	$oldCode{$subPackage}{$subName} = \&{$subPackage."::".$subName};

	my $delimiter = "ANALYZER($subPackage\::$subName):   ";

	my @returnValues = ();

	*{$subPackage."::".$subName} = sub { 
			print "$delimiter =============== Aufruf von $subPackage\::$subName gestart ===============\n";
			my @pars = @_;
			my $showThisData = $optionen{showData}{$subPackage}{$subName};
			my $thisSub = $optionen{subRefs}{$subPackage}{$subName};
			if($showThisData) {
				if($thisSub) {
					print "$delimiter Parameter von $subPackage\::$subName VOR dem Durchlaufen der eingestellten Funktion\n";
				} else {
					print "$delimiter Parameter von $subPackage\::$subName\n";
				}
				_showData(\@pars);
			}
			if($optionen{subRefs}{$subPackage}{$subName}) {
				foreach my $counter (0 .. $#pars) {
					$pars[$counter] = &{$thisSub}($pars[$counter]);
				}
				if($showThisData) {
					print "$delimiter Parameter von $subPackage\::$subName NACH dem Durchlaufen der eingestellten Funktion\n";
					_showData(\@pars);
				}
			}
			if($optionen{reallyExecute}{$subPackage}{$subName}) {
				{
					my $thisSize = _getSizeIfPossible(\@pars);
					if ($thisSize != -1) {
						print qq#$delimiter Die Größe der übergebenen Parameter beträgt $thisSize byte Arbeitsspeicher\n#;
					}
				}
				my $start = gettimeofday();
				if(wantarray == 1) {
					@returnValues = &{$oldCode{$subPackage}{$subName}}(@pars);
				} elsif(wantarray == 0) {
					my $tmp_ret = &{$oldCode{$subPackage}{$subName}}(@pars);
					push @returnValues, $tmp_ret;
				} else {
					&{$oldCode{$subPackage}{$subName}}(@pars)
				}
				my $end = gettimeofday();

				if(scalar @returnValues) {
					if($showThisData) {
						print "$delimiter Der Aufruf gab folgende Rückgabewerte: \n";
						_showData(\@returnValues);
					}
					my $thisSize = _getSizeIfPossible(\@returnValues);
					if($thisSize != -1) {
						print "$delimiter Die Rückgabewerte belegen $thisSize byte Arbeitsspeicher\n";
					}
				}

				print "$delimiter Laufzeit: ".($end - $start)."\n";

				if(scalar @returnValues == 1) {
					print "$delimiter =============== $subPackage\::$subName beendet ===============\n";
					return $returnValues[0];
				} else {
					print "$delimiter =============== $subPackage\::$subName beendet ===============\n";
					return @returnValues;
				}
			} else {
				print "$subPackage\::$subName nicht ausgeführt.\n";
			}
			print "$delimiter =============== $subPackage\::$subName beendet ===============\n";
		};
}

=begin nd
heal stellt die Original-Sub wieder her.
=cut

sub heal {
	my $self = shift;
	my $subPackage = $optionen{subPackage};
	my $subName = $optionen{subName};

	no strict 'refs';
	no warnings 'redefine';
	*{"$subPackage\::$subName"} = \&{$oldCode{$subPackage}{$subName}};
}

=begin nd
reinject installiert wieder den Debug-Code in die Methode.
=cut

sub reinject {
	my $self = shift;
	my $subPackage = $optionen{subPackage};
	my $subName = $optionen{subName};

	no strict 'refs';
	no warnings 'redefine';
	_injectCode($self, $subPackage, $subName);
}

=begin nd
_getSizeIfPossible versucht, dsa Modul Devel::Size zu laden. Wenn es vorhanden ist, wird angezeigt, wie groß die einzelnen Variablen und Rückgabewerte usw. sind. Wenn nicht, wird -1 zurückgegeben und es wird nichts angezeigt. 

Diese Methode sollte nur von innerhalb des Modules aufgerufen werden.
=cut

sub _getSizeIfPossible {
	my $vals = shift;
	my $size = -1;
	eval 'use Devel::Size qw(total_size); $Devel::Size::warn = 0; $size = total_size($vals);';
	return $size;
}

=begin nd
_showData zeigt komplexe Datenstrukturen anschaulich an, ähnlich wie Data::Dumper. 
Es benötigt eine Referenz der Datenstruktur. 

Diese Methode sollte nur von innerhalb des Modules aufgerufen werden.
=cut

sub _showData {
	$| = 1;
	my $data = shift;
	my $indent = shift || 1;
	if ($indent > 10) {
		print(("\t" x $indent)."Mögliche Rekursion: Es werden keine tieferen Datenebenen angezeigt!\n");
		return;
	}
	
	no warnings;
	if(ref($data)) {
		if(ref($data) eq "ARRAY") {
			print(("\t" x $indent)."Array (\n"); 
			foreach (sort {$a <=> $b || $a cmp $b } @{$data}) {
				_showData($_, $indent + 1);
			}
			print(("\t" x $indent)."),\n");
		} elsif (ref($data) eq "HASH") {
			print(("\t" x $indent)."Hash (\n"); 
			foreach (sort {$a <=> $b || $a cmp $b } keys %{$data}) {
				_showData("$_ => $data->{$_}", $indent + 1);
			}

			print(("\t" x $indent)."),\n");
		} elsif(ref($data) eq "CODE") {
			_showData("Code-Referenz()", $indent);
		} elsif(ref($data) eq "GLOB") {
			_showData("Glob-Referenz()", $indent);
		} else {
			_showData("".ref($data)."-Object", $indent);
		}
	} else {
		$data =~ s/'/\\'/g;
		print(("\t" x $indent)."'$data',\n");
	}
	use warnings;
}

1;
