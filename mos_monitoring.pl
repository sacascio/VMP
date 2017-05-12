#!/usr/bin/perl -w
#
#
use strict;
use Data::Dumper;
use DateTime;
use REST::Client;
use JSON;
use Net::DNS;
use Email::Stuffer;
use Email::Sender::Transport::SMTP ();
use Cwd 'abs_path';

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
my $svcip = getsvcip();
my $capip = getcaptureip();

my @messages;
my @captmsg;
my $json_data;
my $svc;
my @asset_list;
my $filtertime = eventfiltertime();
my $script = abs_path($0);

   if ( $svcip eq '0.0.0.0' ) {
     push(@messages,"Could not Get IP address for service-mgr.orgn.orgbny.cv.net");
   }

my $nodestatusurl = '/v2/regions/region-0/nodestatuses';
my $appstatusurl = '/v2/serviceinstances/ums-0-1/appstatuses';
my $servicestatusurl = '/v2/serviceinstances/ums-0-1/servicestatuses';
my $eventsurl = '/v2/serviceinstances/ums-0-1/events' . '?' . $filtertime;
my $captureurl = '/v1/assetWorkflows/live/assets';

# Get List of Assets
$json_data = api_query($capip,'7001',$captureurl);
@asset_list = get_assets($json_data); 

# NODE STATUS
$json_data = api_query($svcip,'8043',$nodestatusurl);
check_nodestatus($json_data);

# APP STATUS
$json_data = api_query($svcip,'8043',$appstatusurl);
check_appstatus($json_data);

# Service STATUS
$json_data = api_query($svcip,'8043',$servicestatusurl);
check_svcstatus($json_data);

# EVENTS
$json_data = api_query($svcip,'8043',$eventsurl);
check_events($json_data);

# Per Channel Status
foreach $svc (@asset_list) {
 $json_data = api_query($capip,'7001',$captureurl . '/' .  "$svc");
 check_capture($json_data,1);
}

my $nummsg = @messages;
my $i;
my %svch;

for ( $i=0; $i < $nummsg; $i++ ) {

  if ( $messages[$i] =~ /NOT CAPTURING/ ) {
    $messages[$i] =~ m/SERVICE (.*) NOT CAPTURING.*/;
    $svc = $1;
 
    if ( ! exists $svch{$svc} ) {
     $svch{$svc} = 1;
     api_restart($capip,'7001',$captureurl . '/' .  "$svc");
     sleep 30;
     $json_data = api_query($capip,'7001',$captureurl . '/' .  "$svc");
     check_capture($json_data,0);
    }

  }
}


for($i = 0; $i < $nummsg; $i++ ) {
  if ( ($messages[$i] =~ /NOT CAPTURING/ ) && ($messages[$i] !~ /SERVICE RESTART/) ) {
    splice(@messages,$i,1);
    $i = -1;
    $nummsg = @messages;
  } 
}

push(@messages,@captmsg);
## Alert and notification

if ( @messages ) {
 emailNow(\@messages);
 archive_logs();
}

sub api_query {
my $ip = shift;
my $port = shift;
my $url = shift;
my $server;

$server = "https://$ip:$port";

my $client = REST::Client->new(host => $server); 
   $client->getUseragent()->ssl_opts(SSL_verify_mode =>0);
   $client->GET($url);

   my $json = decode_json($client->responseContent()); 
   return $json; 
}

sub check_nodestatus {

 my $json_data = shift;

   foreach my $item (@{$json_data}) {
    my $host = $item->{'id'};
       $host =~ s/smregion_0_status.smnodestatus.smregion_0.smnode.//g;
    my $fault =  $item->{'properties'}->{'faultStatus'};
    
      if ( $fault ne 'None' ) {
        push(@messages,"IPTV MOS Host $host, NodeStatus Manager is $fault");
      }
   }

    return;
}

sub check_appstatus {

 my $json_data = shift;
   foreach my $item (@{$json_data}) {
      my $app = $item->{'properties'}->{'appName'};
      my $status = $item->{'properties'}->{'slaStatus'}->{'nodeStatus'};
         if ( $status ne 'normal' ) {
            push(@messages,"IPTV MOS APP: $app, STATUS is $status");
         }
   }

   return;
}

sub check_svcstatus {

 my $json_data = shift;
 
   foreach my $item (@{$json_data}) {
    my $host = $item->{'name'};
    my $status = $item->{'properties'}->{'opStatus'};
        if ( $status ne 'active' ) {
         push(@messages,"IPTV MOS Host $host, status of service $host is $status");
        } 
   }
    return;
}

sub check_events {

 my $json_data = shift;
   foreach my $item (@{$json_data}) {
      if ( $item->{'properties'}->{'severity'} ne 'info' ) {
        my $detail = $item->{'properties'}->{'detailText'};
        my $ts =  $item->{'properties'}->{'eventTime'};
        my $ip =  $item->{'properties'}->{'location'}->{'ipAddr'};
            push(@messages,"EVENT: $detail, TIME: $ts, HOST: $ip");
      }
   }
    return;
}

sub check_capture {

 my $json_data = shift;
 my $append = shift;
 my $puburl;
 my $stat;

  my $service = $json_data->{'contentId'};
  my $tl_status =  $json_data->{'status'}->{'state'};

     # On recheck, if succcessful, update messages  
     if ( $append == 0 ) {

           if ( $tl_status eq 'CAPTURING' ) {

                foreach my $item (@{$json_data->{'output'}}) {
                    foreach my $item2 (@{$item->{'variants'}}) {
                       if ( $item2->{'version'} == 3 ) {
                         $puburl = $item2->{'publishUrl'};
                       }
                     }
                }

               foreach my $item (@{$json_data->{'status'}->{'captureStatus'}}) {
                 my $captureEngine = $item->{'captureEngine'};
                   foreach my $item2 (@{$item->{'streams'}}) {
                         my $profile = $item2->{'name'};
                         my $reason =  $item2->{'reason'};
                        
                           if ( $reason ) {
                                  push(@captmsg,"SERVICE $service IS NOW CAPTURING. PROFILE BIT RATE: $profile.  Capture Engine: $captureEngine.  Publish URL: $puburl.  Reason: $reason. SERVICE RESTART SUCCESSFUL");
                           } else {
                                  push(@captmsg,"SERVICE $service IS NOW CAPTURING. PROFILE BIT RATE: $profile.  Capture Engine: $captureEngine.  Publish URL: $puburl.  SERVICE RESTART SUCCESSFUL");
                           }
                  }
                }
          }
       }
 
        if ( $tl_status ne 'CAPTURING' ) {

           foreach my $item (@{$json_data->{'output'}}) {
              foreach my $item2 (@{$item->{'variants'}}) {
                   if ( $item2->{'version'} == 3 ) {
                      $puburl = $item2->{'publishUrl'};
                   }
                }
              }

              foreach my $item (@{$json_data->{'status'}->{'captureStatus'}}) {
                 my $captureEngine = $item->{'captureEngine'};
                   foreach my $item2 (@{$item->{'streams'}}) {
                          if (  $item2->{'state'} ne 'CAPTURING' ) {
                               my $profile = $item2->{'name'};
                               my $reason =  $item2->{'reason'};

                               if ( $append ) {
                                 if ( $reason ) {
                                   push(@messages,"SERVICE $service NOT CAPTURING. PROFILE BIT RATE: $profile.  Capture Engine: $captureEngine.  Publish URL: $puburl.  Reason: $reason"); 
                                 } else {
                                   push(@messages,"SERVICE $service NOT CAPTURING. PROFILE BIT RATE: $profile.  Capture Engine: $captureEngine.  Publish URL: $puburl"); 
                                }
                              } else {
                                if ( $reason ) {
                                 push(@captmsg,"SERVICE $service NOT CAPTURING. PROFILE BIT RATE: $profile.  Capture Engine: $captureEngine.  Publish URL: $puburl.  Reason: $reason. SERVICE RESTART FAILED"); 
                                } else {
                                 push(@captmsg,"SERVICE $service NOT CAPTURING. PROFILE BIT RATE: $profile.  Capture Engine: $captureEngine.  Publish URL: $puburl.  SERVICE RESTART FAILED"); 
                                }

    
                              }
                          }
                   }
              }

        } 
}


sub getsvcip {

my $res = Net::DNS::Resolver->new(
      nameservers => ["10.250.68.134"], 
      udp_timeout => 3
    );

my $rr;
my $addr = '0.0.0.0';
my $reply = $res->search("service-mgr.orgn.orbgny.cv.net");

  if ( $reply ) {
     foreach my $rr ($reply->answer) {
       if ( $rr->type eq "A" ) {
         $addr = $rr->address;
       }
   }
  } 
         return $addr;

}

sub getcaptureip {

my $res = Net::DNS::Resolver->new(
      nameservers => ["10.250.68.134"], 
      udp_timeout => 3
    );

my $rr;
my $addr = '0.0.0.0';
my $reply = $res->search("am-capture-ums-0-1.orgn.orbgny.cv.net");

  if ( $reply ) {
     foreach my $rr ($reply->answer) {
       if ( $rr->type eq "A" ) {
         $addr = $rr->address;
       }
   }
  } 
         return $addr;

}

sub eventfiltertime {

my $st = `/bin/date -u +"%Y-%m-%dT%H:%M:%S.000Z" -d "10 min ago"`;
my $et = `/bin/date -u +"%Y-%m-%dT%H:%M:%S.000Z"`;

chomp($et);
chomp($st);

return "startTime=" . $st . '&' . "endTime=" . $et;
}

sub get_assets {

my $json_data = shift;
my @i;

foreach my $item (@{$json_data}) {
   push(@i,$item->{'contentId'});
}

   return @i;
}

sub emailNow {
        my $date    = `/bin/date +%m/%d/%Y`;
        $date       =~ s/\r|\n//g;

        my $message = shift;

        my $body = '<h3>Hello,</h3><br>
        <br>
        <b>IPTV/MOS Alert found!!</b><br> ' . "\n" . '<br>' ;

        foreach ( @$message ) {
           $body .= $_ . '<br>' . "\n";
        }

            $body .= '<br>';


       Email::Stuffer->to('cquinn3@cablevision.com')
                      ->from('iptv@dsops3.ds.cv.net')
                      ->subject('MOS IPTV Alert '.$date)
                      ->html_body($body)
                      ->transport(Email::Sender::Transport::SMTP->new({
                        host => 'biscmail.cv.net',
                        }))
                      ->send;


}

sub api_restart {
my $ip = shift;
my $port = shift;
my $url = shift;
my @array;

my $server = "https://$ip:$port";
my $client = REST::Client->new(host => $server);
   $client->getUseragent()->ssl_opts(SSL_verify_mode =>0);
   $client->GET($url);

   my $json = decode_json($client->responseContent());
   $json->{"restart"} = JSON::true;
   delete $json->{"status"};
   delete $json->{"output"};
   $json = encode_json($json);

   $client->PUT($url,$json, {"Content-Type" => "application/json"});
}

sub archive_logs {

my @mce = ( '10.250.68.135','10.250.68.136','10.250.68.137','10.250.68.138');
my $time = time;

 foreach my $m (@mce) {
  `/usr/bin/ssh admin\@$m "cd /var/log/opt/cisco/mos/errorlog ; /usr/bin/tar -cvf saveliveerrorlogs.$time Live* live* 2>/dev/null ;  /usr/bin/gzip -9 saveliveerrorlogs.$time"`;
 }

}
