#!perl.exe

use feature ':5.10'; # say works

my $debug = $ARGV[0];  # set first argument to run some simple tests

$| = 1;  # non buffered STDOUT

use strict;
package MyWebServer;

# we need the local LAN and public WAN addresses
# ipify.org returns the public IP
my $WANIP = HTTPGetPage('https://api.ipify.org');
say 'WAN IP: ' . $WANIP;
my $LANIP = GetPrivateIP();
say 'LAN IP: ' . $LANIP;

use Template;  # this will let us use [% DIRECTIVE %] in any template file and replace them with content
my $tt = Template->new({
      INTERPOLATE => 0, # is 1 it lets us use $x vars instead of [$ x %] syntax
      ENCODING => 'utf8',
      ABSOLUTE => 1, # full path is required if true
      ANYCASE => 1,  # [% x %] or [% X %]
      INCLUDE_PATH => 'include', # look in this folder, too
      ERROR      => 'error.tt',
   }) or die $Template::ERROR;

# set up a simple web server
use HTTP::Server::Simple::CGI;
use base qw(HTTP::Server::Simple::CGI);

use SSDB; # a simple database module that makes a Database from a hash
my $DB = SSDB->new('SettingsDB'); # two files named SettingsDB will appear on disk- its really a hash

use Cwd;
my $path = getcwd;
say 'Path: ' . $path;

# various simple diagnostics
if ($debug) {

   use File::Copy;
   move ('SettingsDB.dir', 'SettingsDB.dir.bak');
   move ('SettingsDB.pag', 'SettingsDB.pag.bak');

   $DB->write('test',1);
   if ($DB->read('test') != 1)
   {
      say 'Error, db failed to write - check perms on folder, there is no write access for you';
      exit 1;
   } else {
      say 'SettingsDB is working';
   }

   move ('SettingsDB.dir.bak', 'SettingsDB.dir');
   move ('SettingsDB.pag.bak', 'SettingsDB.pag');


   # test OsGrid ability to get a X,Y address
   say 'y: ' . GetFree('x');
   say 'x: ' . GetFree('y');

   use FakeCGI;
   my $cgi = new FakeCGI($DB);

   # test each fn()
   &loopback($cgi);
   &index($cgi);
   &config($cgi);
   &save($cgi);
   &start($cgi);
   &stop($cgi);
   exit;
}


# The urls the webserver will process
my %dispatch = (
   '/'         => \&index,
   '/config'   => \&config,
   '/save'	   => \&save,
   '/start'    => \&start,
   '/stop'     => \&stop,
   '/loopback' => \&loopback,
   );

my $WebPort  = '8080';
# start the server on port 8080
 my $web = MyWebServer->new($WebPort);
$web->host($LANIP);

my $pid = $web->background();

say "Please wait for disgnostics to finish.";

# Try the WAN IP first to see if thwe router is okay and web server is up
my $TESTIP = $WANIP;
my $loopbackdata = HTTPGetPage('http://' . $TESTIP . ':' . $WebPort . '/loopback');
my @count = $loopbackdata =~ /loopback/g;
# there are 90 "loopbacks" in the test page
if (scalar @count eq 90)
{
   say ('Router loopback works. Opensimulator server will use the WAN IP address ' . $WANIP);
   $TESTIP= $WANIP;
   $DB->write('ExternalHostName', $WANIP );
} else {
   $loopbackdata = HTTPGetPage('http://' . $LANIP . ':' . $WebPort . '/loopback');
   @count = $loopbackdata =~ /loopback/g;
   if (scalar @count eq 90){
      say ('Router loopback did not work. Setting Opensimulator server to use the local LAN IP address ' . $LANIP);
      $DB->write('ExternalHostName', $LANIP );
   } else {
      say 'Loopback test failed, web server failed to start';
   }
}
exit;

######## END MAIN ########

=pos
handle_request() is a callback from MyWebServer to handle the dispatching of the web page
=cut

sub handle_request {
  my $self = shift;
  my $cgi  = shift;

  my $path = $cgi->path_info(); # currently unused.
  my $handler = $dispatch{$path}; # get pointer to our Perl func that is the web page handler

  if (ref($handler) eq "CODE") {
      print "HTTP/1.0 200 OK\r\n"; # print standard response header
      $handler->($cgi);

  } else {
      say "HTTP/1.0 404 Not found\r\n";
      print $cgi->header,
            $cgi->start_html('Not found'),
            $cgi->h1('Not found'),
            $cgi->end_html;
  }
}

=pod
loopback() paints a large chunk of data to test the ability of the router to loop back to private LAN from publiuc WAN
=cut

sub loopback {
   my $cgi = shift;
   my $content = { Title => "Opensimulator",};
   MakeHTML($cgi,'loopback.tt',$content);
};


=pod
index() paints a web page after stashing away the form vars.
=cut

sub index {
   my $cgi = shift;
   my $content = {   Title => "Opensimulator",
                     HTML => "Welcome to Opensimulator Simple Setup",
                  };
   MakeHTML($cgi,'index.tt',$content);
};

=pod
save() paints a web page after stashing away the form vars.
=cut

sub save {
   my $cgi = shift;

   my $errormsg;
   my $RegionName = $cgi->param('RegionName');
   if ($RegionName eq 'Choose a Name' || ! $RegionName  )
   {
      $errormsg = 'Please choose a new name for your home simulator.';
   } else {
      $DB->write('RegionName',$cgi->param('RegionName'));
   }

   use UUID::Tiny  ':legacy';
   my $UUID = $cgi->param('UUID');
   if (! is_UUID_string($UUID) ) {
      $UUID = uc(create_UUID_as_string(UUID_V1));
      $errormsg = 'UUID was not legal - a new one has been assigned';
   }

   $DB->write('UUID',      $UUID);
   $DB->write('LocX',      $cgi->param('LocX')) if $cgi->param('LocX');
   $DB->write('LocY',      $cgi->param('LocY')) if $cgi->param('LocY');
   $DB->write('Port',      $cgi->param('Port')) if $cgi->param('Port');
   $DB->write('ExternalHostName',  $cgi->param('ExternalHostName')) if $cgi->param('ExternalHostName');
   $DB->write('SYSTEMIP',  $cgi->param('SYSTEMIP')) if $cgi->param('SYSTEMIP');



   my $body;
   if (! $errormsg)
   {
      my $output;
      my $content = {
                     RegionName => $RegionName,
                     UUID 		=> $UUID,
                     LocX 		=> $cgi->param('LocX'),
                     LocY 		=> $cgi->param('LocY'),
                     Port 		=> $cgi->param('Port'),
                     ExternalHostName => $cgi->param('ExternalHostName'),
                     SYSTEMIP => $cgi->param('SYSTEMIP'),
              };

      # update the tags in Regions.ini
      $tt->process($path .'/include/' . 'Regions.ini.example', $content, \$output);
      if (open (INI, ">$path/opensimtest/bin/Regions/Region.ini"))
      {
         print INI $output;
         close INI;
      }

      # now for Opensim.ini
      $tt->process($path .'/include/' . 'Opensim.ini.example', $content, \$output);
      if (open (INI, ">$path/opensimtest/bin/Opensim.ini"))
      {
         print INI $output;
         close INI;
      }
      $body = 'Setup is complete.' ;
   } else {
      $body = 'Setup is incomplete.' ;
   }

   my $content = { Title => 'Saved', HTML => $body, ErrorMsg => $errormsg};
   MakeHTML($cgi,'template.tt',$content);
}

=pod
config() paints a form web page after fetchign, or making a default form .
=cut

sub config {
   my $cgi = shift;
   # test for or make default values

   my $RegionName = $DB->read('RegionName');  # gets it from the db, if any
   if (! $RegionName) {                      # no?
      $RegionName = 'Choose a Name';         # set reasonableness
      $DB->write('RegionName',$RegionName);  # save it
   }

   use UUID::Tiny  ':legacy';
   my $UUID = $DB->read('UUID');
   if (! $UUID) {
      $UUID = uc(create_UUID_as_string(UUID_V1));
      $DB->write('UUID',$UUID);
   }
   # even if we read it, the user may have changed it, and it may be no good, let's check:
   if (! is_UUID_string($UUID) ) {
      $UUID = uc(create_UUID_as_string(UUID_V1));
      $DB->write('UUID',$UUID);
   }

   # X, Y locations are critical as it will fail if we lay on top of another - get them from osGrid
   my $LocX = $DB->read('LocX');
   if (! $LocX) {
      $LocX = GetFree('x');
      $DB->write('LocX',$LocX);
   }
   my $LocY = $DB->read('LocY');
   if (! $LocY) {
      $LocY = GetFree('y');
      $DB->write('LocY',$LocY);
   }

=pod
PORT

The default Region port is 9000.  They can change it. It's TCP and UDP
The http_listener_port configured in the [Network] section of OpenSim.ini needs to be accessible externally. By default this is 9000.
The configured InternalPort of each region needs to be accessible for UDP traffic from the viewer
(to exchange movement data, object information, etc.). These configuration files are found in the
bin/Regions/ directory. The usual port for the first region is 9000, but each region needs its own port
(usually then 9001, 9002, etc.). However, any other set of ports can also be configured.
=cut

   my $Port = $DB->read('Port');
   if (! $Port) {
      $Port = 9000;
      $DB->write('Port',$Port);
   }

   # PUBLIC IP that is found on the outside of the firewall. Could also be localhost, or 127.0.0.1, which is not remotely connectable.
   # For Hypergating or allowing others to visit, this MUST be the public IP or DNS name of the router.
   my $ExternalHostName  = $DB->read('ExternalHostName');
   if (! $ExternalHostName ) {
     $ExternalHostName  =  $WANIP;
     $DB->write('ExternalHostName ',$ExternalHostName );
   }

   # Private  IP that is found on the inside of the firewall. Could be localhost, or 127.0.0.1, which is not remotely connectable.
   # Preferably the actual IP, or SYSTEMIP, both of which are connectable.
   my $SYSTEMIP = $DB->read('SYSTEMIP');
   if (! $SYSTEMIP) {
     $SYSTEMIP =  $LANIP;
     $DB->write('SYSTEMIP',$SYSTEMIP);
   }

   my $content = {	RegionName => $RegionName,
                     UUID 		=> $UUID,
                     LocX 		=> $LocX,
                     LocY 		=> $LocY,
                     Port 		=> $Port,
                     ExternalHostName => $ExternalHostName,
                     SYSTEMIP => $SYSTEMIP,
              };

   MakeHTML($cgi,'setup.tt',$content);
}


sub start {
   my $cgi = shift;
   # stubs for now. Should start the Opensim in console mode as a forked task, and display a Ajax page attached to the console
   my $content = {HTML => 'a stub' };
   MakeHTML($cgi,'start.tt',$content);
}

sub stop{
   my $cgi = shift;
   my $content = {HTML => 'a stub'};
   MakeHTML($cgi,'stop.tt',$content);
}


###########################################
############## UTILITY FUNCTIONS ##########

=pod
MakeHTML() uses Template Toolkit to paint web pages.   This keeps the HTML out of code.
=cut

sub MakeHTML {
   use Template;
   my $cgi = shift;
   my $page = shift; # page file name, usually *.tt
   my $content= shift;  # a ref to the data structure we want the Template to fill in.

   my $output;
   $tt->process($path . '/'. $page, $content, \$output);

   print $cgi->header;
   print $output;
}

=pod
We need the public-facing IP address for Opensim if we are running in a HG or Grid mode.
=cut

sub HTTPGetPage {
   my $URL = shift || die 'no parameter';
   use LWP::UserAgent;
   my $ua = LWP::UserAgent->new;
   my $req = HTTP::Request->new(GET => $URL);# Create a request
   my $res = $ua->request($req); # Pass request to the user agent and get a response back
   if ($res->is_success) {  # Check and get the outcome of the response
      return $res->content;
   }
   return;
}

#   http://www.osgrid.org/index.php/opencoordinates returns a table of open spots:
# GetFree(x|y) returns the global coorrds of a free spot at OsGrid
sub GetFree {
   my $loc = shift; # get x or y
   return unless $loc eq 'x' or $loc eq 'y';

   my $x = $DB->read('X') || 0;
   my $y = $DB->read('Y') || 0;

   # return the saved database values.
   return $x if $x && $loc eq 'x';
   return $y if $y && $loc eq 'y';

   # not found an empty location yet. Go get one
   use LWP::UserAgent;
   my $ua = LWP::UserAgent->new;

   my $map = 'http://www.osgrid.org/index.php/opencoordinates';

   my $req = HTTP::Request->new(GET => $map);
   my $res = $ua->request($req); # Pass request to the user agent and get a response back
   if ($res->is_success) {
      my $result = $res->content;
      $result =~ s/\n//g; # make it a flat string with no new lines
      $result =~ /<tbody>(.*)<\/tbody>/;
      $result = $1;

=pod
      <tbody>
         <tr>
         <td><center>10006</td>
         <td><center>10001</td>
         <td><center>1,557 m</td>
         <td><center>6</td>
         <td><center>Hentai, Panthar15, Panthar14, Hispalis, Panthar13, Panthar12</td>
     </tr>
=cut

      $result =~ s/<center>(\d+?)<\/td>//i;
      $x = $1;
      $result =~ s/<center>(\d+?)<\/td>//i;
      $y = $1;
      $DB->write('X',$x); # save it away
      $DB->write('Y',$y);
   }
   return $x if $loc eq 'x';
   return $y if $loc eq 'y';
   0;
}

sub GetPrivateIP {
   # Get the local system's IP address that is on this LAN
   use Sys::Hostname;
   use Socket;
   my $address = inet_ntoa((gethostbyname(hostname))[4]);
   if ($address eq '127.0.0.1' || $address !~ /^\d+\.\d+\.\d+\.\d+$/ || $address eq $WANIP)
   {
         $address = 'localhost';
   }

   return $address;
}