#!/usr/bin/perl -w
#
use strict;
my $str;

open(FILE,"callsigns") or die "Can't open callsigns\n";

$str = <<EOF;
{
	"id": "smtenant_0.smchannellineup.Hicksville",
	"name": "Hicksville",
	"type": "channellineups",
	"externalId": "/v2/channellineups/Hicksville",
	"properties": {
		"description": "Hicksville Lineup",
		"sourcesRef": [
EOF
 
while(<FILE>) {
	chomp($_);
	$_ =~ s/_/-/g;
        $_ =~ s/\s+/-/g;	
	
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
`curl -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2" -ks https://service-mgr.mos.hcvlny.cv.net:8043/v2/channellineups/Hicksville -H Content-Type:application/json -X POST -d \@build`;
`curl -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2" -ks https://service-mgr.mos.hcvlny.cv.net:8043/v2/channellineups/Hicksville -H Content-Type:application/json -X PUT -d \@build`;
unlink("build");
