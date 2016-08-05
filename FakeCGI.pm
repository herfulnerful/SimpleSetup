# for tests only- makes a fake HTTP::Server::Simple::CGI so we can run under Komodo debug levels on Windows

package FakeCGI;
use strict;
use warnings;

sub new {
   my $class = shift;
   my $self = {};
   $self->{DB} = shift;
   bless ($self, $class);
   return $self;
}

sub header {
   my $self = shift;
   return "200 OK\n";
}

sub start_html {
   my $self = shift;
   return "<HTML>\n";
}
sub p {
   my $self = shift;
   my $value = shift;
   print "<p>";
   print $value;
   return "</p>\n";
}

sub end_html {
   my $self = shift;
   return "</HTML>\n";
}
sub param {
   my $self = shift;
   my $param = shift;
   my $DB = $self->{DB};
   return $DB->read($param);
}
1;
