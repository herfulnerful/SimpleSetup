package SSDB;
use strict;
use warnings;

sub new {
   my $class = shift;
   my $dbname = shift; # database name = INI, typically.
   my $self = {};
   $self->{DBName} = $dbname;
   bless ($self, $class);
   return $self;
}

sub read {
   my $self = shift;
   my $name = shift;

   my %INI;
   dbmopen(%INI,$self->{DBName},0666);

   my $value = $INI{$name};

   dbmclose(%INI);
   return $value;
}

sub write {
   my $self = shift;
   my $key = shift;
   my $val = shift;
   my %INI;
   dbmopen(%INI,$self->{DBName},0666);
   $INI{$key} = $val;
   dbmclose(%INI);
}

1;
