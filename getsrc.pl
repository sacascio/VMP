#!/usr/bin/perl -w

use strict;
use JSON;
use Getopt::Std;

my %opts;

getopts('hd:', \%opts);

usage() if ( ! %opts );
usage() if ( !$opts{d} ) ;

my $domain = $opts{d};
my @data;
my $d;
my $sm = 'service-mgr.' . $domain;
my $token = gettoken($sm);

open(FILE,">mos_channel_config.csv") or die "can't open $!\n";

@data = `curl -3 -ks -H "Authorization: Bearer $token" https://$sm:8043/v2/channelsources/ | grep channelId `;

foreach(@data) {
	chomp($_);
	$_ =~ s/channelId//g;
	$_ =~ s/\"//g;
	$_ =~ s/,//g;
	$_ =~ s/://g;
	$_ =~ s/\s+//g;
	
	$d = `curl -3 -ks -H "Authorization: Bearer $token" https://$sm:8043/v2/channelsources/$_ `;
	$d =~ m/sourceUrl\": \"udp:\/\/(.*):4001\"/;
	my $mc = $1;

	$d =~ m/\"sourceIpAddr\": \"(.*)\"/;
	my $sip = $1;

	print FILE "$_,$sip,$mc\n";
}	

close FILE;


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
h:      Help message

EOF

exit;
}

