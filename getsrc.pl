#!/usr/bin/perl -w

use strict;
my @data;
my $d;

open(FILE,">mos_channel_config.csv") or die "can't open $!\n";

@data = `curl -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2" -ks https://service-mgr.mos.hcvlny.cv.net:8043/v2/channelsources/ | grep channelId `;

foreach(@data) {
	chomp($_);
	$_ =~ s/channelId//g;
	$_ =~ s/\"//g;
	$_ =~ s/,//g;
	$_ =~ s/://g;
	$_ =~ s/\s+//g;
	
	$d = `curl -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2" -ks https://service-mgr.mos.hcvlny.cv.net:8043/v2/channelsources/$_ `;
	$d =~ m/sourceUrl\": \"udp:\/\/(.*):9001\"/;
	my $mc = $1;

	$d =~ m/\"sourceIpAddr\": \"(.*)\"/;
	my $sip = $1;

	print FILE "$_,$sip,$mc\n";
}	

close FILE;
