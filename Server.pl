#!perl.exe

use feature ':5.10';

my $debug = 1; # set to a true value to run some simple tests
$| = 1;  # non buffered STDOUT
{
   use strict;
   package MyWebServer;

   use Template;
   use HTTP::Server::Simple::CGI;
   use base qw(HTTP::Server::Simple::CGI);

   # Get the local system's IP address that is "en route" to "the internet":
   use Sys::Hostname;
   use Socket;
   my $address = inet_ntoa((gethostbyname(hostname))[4]);

   warn ('IP address is not public') unless $address ne '127.0.0.1';

   # a possible cure for problems with Ip addresses not being public
   #use Net::Address::IP::Local;
   #my $address      = Net::Address::IP::Local->public;

   use SSDB; # a simple database made from a hash
   my $DB = SSDB->new('SettingsDB'); # two files named SettingsDB will appear on disk

   # various simple diagnostics
   if ($debug) {
      $DB->write('test',1);
      if ($DB->read('test') != 1)
      {
         print 'Error, db failed to write - check perms on folder\n';
         exit 1;
      } else {
         say 'SettingsDB is working';
      }

      # test OsGrid ability to get a X,Y address
      say 'y: ' . GetFree('x');
      say 'x: ' . GetFree('y');

      # ditto for ipify.org
      say 'public IP: ' . GetPublicIP();
   }

   use Cwd;
   my $dir = getcwd;


   my $path = getcwd;
   say 'Path: ' . $path;

   # The urls the webserver will process
   my %dispatch = (
      '/'         => \&home,
      '/config'   => \&config,
      '/save'	   => \&save,
   );


   # start the server on port 80
    my $web = MyWebServer->new(8080);
    if (! $debug) {
      $web->host($address);
    }

   my $pid = $web->background();
   print "Use 'kill $pid' to stop web server.\n";

   exit;

####################################################

   sub handle_request {
     my $self = shift;
     my $cgi  = shift;

     my $path = $cgi->path_info();
     my $handler = $dispatch{$path};

     if (ref($handler) eq "CODE") {
         print "HTTP/1.0 200 OK\r\n";
         $handler->($cgi);

     } else {
         print "HTTP/1.0 404 Not found\r\n";
         print $cgi->header,
               $cgi->start_html('Not found'),
               $cgi->h1('Not found'),
               $cgi->end_html;
     }
   }

   sub home {
      my $cgi = shift;
      my $content = {   Title => "Opensimulator",
                        HTML => "Welcome to Opensimulator Simple Setup",
                     };

      MakeHTML($cgi,'index.tt',$content);
   };

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
      $DB->write('SYSTEMIP',  $cgi->param('SYSTEMIP')) if $cgi->param('SYSTEMIP');

      my $content = { RegionName    => $cgi->param('RegionName'),
                      REGIONUUID    => $UUID,
                      LocX 		   => $cgi->param('LocX'),
                      LocY 		   => $cgi->param('LocY'),
                      PORT 		   => $cgi->param('Port'),
                      SYSTEMIP 	   => $cgi->param('SYSTEMIP'),
                      ErrorMsg      => $errormsg,
                  };

      use Template;  # this will let us use [% DIRECTIVE %] in any template file and replace them with content
      my $tt = Template->new({
            INTERPOLATE => 0, # is 1 it lets us use $x vars instead of [$ x %] syntax
            ENCODING => 'utf8',
            ABSOLUTE => 1, # full path is required if true
            ANYCASE => 1,  # [% x %] or [% X %]
            INCLUDE_PATH => 'include', # look in this folder, too
            ERROR      => 'error.tt',
         }) or die $Template::ERROR;


      my $body;
      if (! $errormsg)
      {
         my $output;
         # update the tags in Regions.ini
         $tt->process($dir .'/include/' . 'Regions.ini.example', $content, \$output);
         if (open (INI, ">$path/opensimtest/bin/Regions/Region.ini"))
         {
            print INI $output;
            close INI;
         }

         # now for Opensim.ini
         $tt->process($dir .'/include/' . 'Opensim.ini.example', $content, \$output);
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


   sub config {
      my $cgi = shift;

      # test and get default values

      my $RegionName = $DB->read('RegionName');
      if (! $RegionName) {
         $RegionName = 'Choose a Name';
         $DB->write('RegionName',$RegionName);
      }

      use UUID::Tiny  ':legacy';
      my $UUID = $DB->read('UUID');
      if (! $UUID) {
         $UUID = uc(create_UUID_as_string(UUID_V1));
         $DB->write('UUID',$UUID);
      }
      # even if we read it, it may be no good, let's check:
      if (! is_UUID_string($UUID) ) {
         $UUID = uc(create_UUID_as_string(UUID_V1));
         $DB->write('UUID',$UUID);
      }

      # X, Y locations are critical - we should get them from osGrid
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

      # the default port is 9000.  They can change it.
      my $Port = $DB->read('Port');
      if (! $Port) {
         $Port = 9000;
         $DB->write('Port',$Port);
      }

      # Public IP that is found on the outside of the firewall
      my $SYSTEMIP = $DB->read('SYSTEMIP');
      if (! $SYSTEMIP) {
        $SYSTEMIP =  GetPublicIP();
        $DB->write('SYSTEMIP',$SYSTEMIP);
      }

      my $content = {	RegionName => $RegionName,
                        UUID 		=> $UUID,
                        LocX 		=> $LocX,
                        LocY 		=> $LocY,
                        Port 		=> $Port,
                        SYSTEMIP => $DB->{SYSTEMIP} || GetPublicIP(),
                 };

      MakeHTML($cgi,'setup.tt',$content);

   }

   sub MakeHTML {
      use Template;
      my $cgi = shift;
      return if !ref $cgi;

      my $page = shift;

      my $content= shift;

      my $tt = Template->new({
            INTERPOLATE => 0,
            ENCODING => 'utf8',
            ABSOLUTE => 1,
            ANYCASE => 1,
            INCLUDE_PATH => 'include',
            ERROR      => 'error.tt',
         }) or die $Template::ERROR;


      my $output;

      $tt->process($path .'/' . $page, $content, \$output);

      print $cgi->header,
            $cgi->start_html("Simple Opensimulator"),
            $cgi->p($output),
            $cgi->end_html;
   }


   # utility functions


   sub GetPublicIP {
      use strict;
      use warnings;
      use LWP::UserAgent;
      my $ua = LWP::UserAgent->new;

      # Create a request
      my $req = HTTP::Request->new(GET => 'https://api.ipify.org');
      # Pass request to the user agent and get a response back
      my $res = $ua->request($req);

      # Check and get the outcome of the response
      if ($res->is_success) {
         return $res->content;
      }
      return;
   }


#   http://www.osgrid.org/index.php/opencoordinates returns a table of open spots:

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
      # Pass request to the user agent and get a response back
      my $res = $ua->request($req);
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
         $DB->write('X',$x);
         $DB->write('Y',$y);
      }
      return $x if $loc eq 'x';
      return $y if $loc eq 'y';
      0;
   }
}