#!/usr/bin/perl -w
#
use Getopt::Std;
use strict;
use JSON;

my %opts;
my $str;
my $sitename;
my $domain;
my $sm;
my $token;

getopts('hn:d:', \%opts);

usage() if ( ! %opts );
usage() if ( ! $opts{n} || !$opts{d} );
usage() if ( $opts{h} );

$sitename = $opts{n};
$domain   = $opts{d};
$sm = 'service-mgr.' . $domain;
$token = gettoken($sm);

open(FILE,"callsigns") or die "Can't open callsigns\n";

$str = <<EOF;
{
	"id": "smtenant_0.smchannellineup.$sitename",
	"name": "$sitename",
	"type": "channellineups",
	"externalId": "/v2/channellineups/$sitename",
	"properties": {
		"description": "$sitename Lineup",
		"sourcesRef": [
EOF
 
while(<FILE>) {
	chomp($_);
	
$str .= <<EOF;

			{
				"sourceRef": "smtenant_0.smchannelsource.$_",
				"contentId": "$_",
				"rightsTag": "common",
				"customConfigs": []
			},
EOF

}

$str =~ s/,$//g;

$str .= <<EOF;
		]
	}
}

EOF

close FILE;

open(BUILD,">build") or die "Can't open build\n";
print BUILD "$str\n";
close BUILD;

# Token following the word Bearer comes from the PAM in /etc/opt/cisco/mos/public/token.json
`curl -H "Authorization: Bearer $token" -ks https://$sm:8043/v2/channellineups/$sitename -H Content-Type:application/json -X POST -d \@build`;
#`curl -H "Authorization: Bearer $token" -ks https://$sm:8043/v2/channellineups/$sitename -H Content-Type:application/json -X POST -d \@build`;
`curl -H "Authorization: Bearer $token" -ks https://$sm:8043/v2/channellineups/$sitename -H Content-Type:application/json -X PUT -d \@build`;

unlink("build");

sub usage {

print <<EOF;

The following parameters are required:

n:  Site Name (No Spaces)
d:  Domain name (ex. mos.hcvlny.cv.net)
h:  Help message


EOF
exit;

}

sub gettoken {
#return "ae3f5992cc054602be1346701aec723bbd4a4af69d510c6ada2f50455e5f9e9c";
my $host = shift;

my $token_file = 'token.json';
`scp -o StrictHostKeyChecking=no  admin\@$sm:/etc/opt/cisco/mos/public/$token_file $token_file > /dev/null 2>&1`;

 
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
