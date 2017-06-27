#!/usr/bin/perl -w

use strict;
use JSON;
use Getopt::Std;

my %opts;

getopts('hd:w:', \%opts);

usage() if ( ! %opts );
usage() if ( !$opts{d} ) ;
usage() if ( !$opts{w} ) ;

my $domain = $opts{d};
my $wf = $opts{w};

`./getsrc.pl -d $domain`;

my $callsign;
my $res;
my $detail;
my $sourceip;
my $mcip;

my $rest_sm = 'controller.' . $domain;
my $sm = 'service-mgr.' . $domain;

my $token=gettoken($sm);

# Parse out callsigns from asset_list
#

open(FILE,"mos_channel_config.csv") or die "Can't open mos_channel_config.csv\n";
open(OUT,">asset_cap_status.csv") or die "Can't open app_cap_status.csv\n";

while(<FILE>) {

	chomp($_);
	$_ =~ m/(.*),.*,.*/;
	$callsign = $1;

	$res = `curl -3 -ks https://$rest_sm:7001/v1/assetWorkflows/$wf/assets/$callsign`;

	
	if ( $res =~  /.* Asset metadata not found.*/ ) {
		print OUT "$callsign,Fail,Asset not found in workflow $wf,NA,NA\n";
		next;
	}
	$res =~ m/.*"sourceUrl":"udp:\/\/.*:\d+","sourceIp":"(\d+\.\d+\.\d+\.\d+)",".*/;

	$sourceip = $1;

	$res =~ m/.*"sourceUrl":"udp:\/\/(.*):\d+","sourceIp.*/;
	$mcip = $1;


	$res =~ m/.*captureStatus(.*)/;
	$detail = $1;
	$detail =~ s/\":\[\{\"instanceId\":\"instance0\",\"state\"://g;
	($detail,$sourceip,$mcip) = parse_log($detail);

	if ( $detail eq "CAPTURING" ) {
		print OUT "$callsign,Pass,$detail,$sourceip,$mcip\n";
	} else {
		print OUT "$callsign,Fail,$detail,$sourceip,$mcip\n";
	}

}

close FILE;
close OUT;


sub parse_log {
my $raw = shift;
my $message;
my $m;
my $final;
my $udp;
my $br;

		chomp($raw);

                if ( $raw eq '":[]}}' ) {
                       return ("Pending State",$sourceip,$mcip);
		}


		if ( $raw =~ /CAPTURING/) {
			return ("CAPTURING",$sourceip,$mcip);
		}

		my @tmp = split(/,/, $raw);
		shift(@tmp);
		shift(@tmp);

			foreach $m (@tmp) {
				$message .= $m;
			}

	
		$message =~ m/.*\[(.*)\].*/;
	        $message =  $1;

		@tmp = split(/\}/, $message);
			foreach $m (@tmp) {
				if ( $m =~ /reason/i ) {
					next if ( $m =~ /Capture IPC Error/ );
					$m =~ s/\"/ /g;
					$m =~ s/name : //g;
					$m =~ s/\{//g;
					$m =~ s/ state : /PROFILE:/g;
					$m =~ s/^\s+//g;
					$m =~ m/^(\d+k) PROFILE.*/;
					$udp = udpMap($1);
					$m = $udp . " BIT RATE " .  $m;
					$final .= $m . ":::";
				}


			}

			if ( ! defined($final) ) {
					$final = $message;
			}

			return ($final,$sourceip,$mcip);

}


sub udpMap {

my $br = shift;

my %hash = (
		'450k'  => 'UDP 4001 (HD)',
		'600k'  => 'UDP 4002 (HD)',
		'1000k' => 'UDP 4003 (HD)',
		'1500k' => 'UDP 4004 (HD)',
		'2200k' => 'UDP 4005 (HD)',
		'4000k' => 'UDP 4006 (HD)',
		'300k'  => 'UDP 4001 (SD)',
		'625k'  => 'UDP 4002 (SD)',
		'925k'  => 'UDP 4003 (SD)',
		'1200k' => 'UDP 4004 (SD)'

		);


return $hash{$br};

}

sub gettoken {

my $host = shift;

my $token_file = 'token.json';
`scp -o StrictHostKeyChecking=no admin\@$sm:/etc/opt/cisco/mos/public/$token_file $token_file > /dev/null 2>&1`;


      my $json_text = do {
      open(my $json_fh, "<:encoding(UTF-8)", $token_file) or die("Can't open \$token_file\": $!\n");
      local $/;
      <$json_fh>
      };

             my $json = JSON->new;
             my $data = $json->decode($json_text);
             my $token =  $data->{tokenMap}{defaultToken}{name};
             unlink($token_file);
             return $token;
}

sub usage {

print <<EOF;

The following parameters are required:

d:      Domain name (ex. mos.hcvlny.cv.net)
w:	Workflow name (ex. live)
h:      Help message

EOF

exit;
}

