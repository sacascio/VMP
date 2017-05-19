#!/usr/bin/perl -w

use strict;
`./getsrc.pl`;

my $callsign;
my $res;
my $detail;
my $sourceip;
my $mcip;
# Parse out callsigns from asset_list
#

open(FILE,"mos_channel_config.csv") or die "Can't open mos_channel_config.csv\n";
open(OUT,">asset_cap_status.csv") or die "Can't open app_cap_status.csv\n";

while(<FILE>) {

	chomp($_);
	$_ =~ m/(.*),.*,.*/;
	$callsign = $1;
	#$res = `curl -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2" -ks https://service-mgr.mos.hcvlny.cv.net:7001/v1/assetWorkflows/live/assets/$callsign`;
	$res = `curl -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2" -ks https://10.249.35.221:7001/v1/assetWorkflows/live/assets/$callsign`;
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
		'450k'  => 'UDP 9001 (HD)',
		'600k'  => 'UDP 9002 (HD)',
		'1000k' => 'UDP 9003 (HD)',
		'1500k' => 'UDP 9004 (HD)',
		'2200k' => 'UDP 9005 (HD)',
		'4000k' => 'UDP 9006 (HD)',
		'300k'  => 'UDP 9001 (SD)',
		'625k'  => 'UDP 9002 (SD)',
		'925k'  => 'UDP 9003 (SD)',
		'1200k' => 'UDP 9004 (SD)'

		);


return $hash{$br};

}
