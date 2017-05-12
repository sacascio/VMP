#!/usr/bin/perl -w
#
#
use strict;
use REST::Client;
use JSON;
use Net::DNS;

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
my $json_data;
my @messages;

my $svcip = getsvcip();

if ( $svcip eq '0.0.0.0' ) {
     #push(@messages,"Could not Get IP address for service-mgr.orgn.orgbny.cv.net");
     $svcip = '10.249.35.222';
}

 my $servicesurl = '/v2/channelsources';
 $json_data = api_query($svcip,'8043',$servicesurl);
 my @ins = parse_channels($json_data);

# FUNCTIONS


sub api_query {
my $svcip = shift;
my $port = shift;
my $url = shift;

my $server = "https://$svcip:$port"; 
my $client = REST::Client->new(host => $server); 
   $client->getUseragent()->ssl_opts(SSL_verify_mode =>0);
   $client->GET($url);
   #added logic to return 0 if JSON is malformed
   if ($client->responseContent() =~ /^Service/)
   {
	return 0;
   }
   my $json = decode_json($client->responseContent());
   return $json;
}

sub getsvcip {

my $res = Net::DNS::Resolver->new(
      nameservers => ["10.249.35.202"],
      udp_timeout => 3
    );

my $rr;
my $addr = '0.0.0.0';
my $reply = $res->search("mos.hcvlny.cv.net");

  if ( $reply ) {
     foreach my $rr ($reply->answer) {
       if ( $rr->type eq "A" ) {
         $addr = $rr->address;
       }
   }
  }
         return $addr;

}


sub parse_channels {

my $json_data = shift;
my $insert;
my @ins;
 
   foreach my $item (@{$json_data}) {
       my $channel = $item->{'name'};
         foreach my $items2 (@{$item->{'properties'}->{'streams'}})  {
               foreach my $items3 (@{$items2->{'sources'}})  {
                    my $url = $items3->{'sourceUrl'};
                    my $sourceIP = $items3->{'sourceIpAddr'};
 
                    $url =~ m/udp:\/\/(.*)\:(.*)/;
                    my $mcIP = $1;
                    my $sp = $2;

                    $insert = '(' . 
                                "'" . $channel       . "'" . ',' .   
                                "'" . $mcIP          . "'" . ',' .   
                                "'" . $sp            . "'" . ',' .   
                                "'" . $sourceIP      . "'" . ',' . 
                                ')' . ',' ;
                    push(@ins,$insert);
               }
         }    
   }
                    return(@ins);
}

