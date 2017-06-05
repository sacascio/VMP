#!/usr/bin/perl -w

use strict;
use JSON;
use Getopt::Std;
use Spreadsheet::XLSX;

# SDL Version 2, using XLSX 
my $callsign;
my $sourceip;
my $type;
my $mcip;
my $str;
my %opts;
my $fname;
my $tname;
my $retcode;
my $description;
my $domain;
my $sm;
my $token;
my $sd_only_1pro = 0;

getopts('hi:t:s', \%opts);

usage() if ( ! %opts );
usage() if ( ! $opts{t} || !$opts{i} || !$opts{d} );
usage() if ( $opts{h} );

$fname  = $opts{i};
$tname  = $opts{t};
$domain = $opts{d};

if ( $opts{s} ) {
	$sd_only_1pro = 1;
}

$sm = 'service-mgr.' . $domain;
$token = gettoken($sm);
$fname = create_input_file($fname,$tname);
exit;

open(FILE,$fname) or die "Can't open $fname\n";
open(ELOG,">elog.txt") or die "Can't open elog.txt\n";
open(CS,">callsigns") or die "Can't open callsigns\n";

while(<FILE>) {
	chomp($_);
	($description,$callsign,$sourceip,$type,$mcip) = split(/,/, $_);

	$type = uc($type);

    print CS "$callsign\n";

    if ( $sd_only_1pro == 0 ) {
	    if ( $type eq 'HD' ) { 
	    #if ( $type =~ /4004/ ) { 
	    	buildSDJsonFile($callsign,$sourceip,$mcip,$description);
	    } else {
	    	buildHDJsonFile($callsign,$sourceip,$mcip,$description);
	    }
    } else {
	    buildSDJsonFile_1pro($callsign,$sourceip,$mcip,$description);
    }
	

	## Add channel to V2P ##
	$retcode = addchannel($callsign,$token,$sm);

	
	if ( $retcode != 200 ) {
		print ELOG "CHANNEL CREATION FAILED: $_\n";
	} 
	
		
	## Delete JSON build File	
	unlink("build");

}		

close FILE;
close ELOG;
close CS;

sub addchannel {
# Token following the word Bearer comes from the PAM in /etc/opt/cisco/mos/public/token.json
my $cs  = shift;
my $t_token = shift;
my $sm = shift;

#`curl -w "%{http_code}" -o /dev/null -k -v -H "Authorization: Bearer $t_token"  https://$sm:8043/v2/channelsources/$cs -H Content-Type:application/json -X POST -d \@build > /dev/null 2>&1`;
my $res = `curl -w "%{http_code}" -o /dev/null -k -v -H "Authorization: Bearer $t_token"  https://$sm:8043/v2/channelsources/$cs -H Content-Type:application/json -X PUT -d \@build 2>/dev/null`;

return $res;

}

sub buildHDJsonFile {
my $cs = shift;
my $sourceip = shift;
my $mc = shift;
my $desc = shift;

$str =  <<EOF;
{
  "id": "smtenant_0.smchannelsource.$cs",
  "name": "$cs",
  "type": "channelsources",
  "externalId": "/v2/channelsources/$cs",
  "properties": {
    "channelId": "$cs",
    "description": "$desc",
    "streamType": "ATS",
    "streams": [
      {
        "profileRef": "smtenant_0.smstreamprofile.450k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4001",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.600k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4002",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.1000k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4003",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.1500k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4004",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.2200k",
 	"sources": [
          {
            "sourceUrl": "udp://$mc:4005",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.4000k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4006",
            "sourceIpAddr": "$sourceip"
          }
        ]
      }
    ]
  }
}
EOF

open(BUILD,">build");
print BUILD "$str\n";
close BUILD;

}

sub buildSDJsonFile {
my $cs = shift;
my $sourceip = shift;
my $mc = shift;
my $desc = shift;

$str =  <<EOF;
{
  "id": "smtenant_0.smchannelsource.$cs",
  "name": "$cs",
  "type": "channelsources",
  "externalId": "/v2/channelsources/$cs",
  "properties": {
    "channelId": "$cs",
    "description": "$desc",
    "streamType": "ATS",
    "streams": [
      {
        "profileRef": "smtenant_0.smstreamprofile.300k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4001",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.625k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4002",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.925k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4003",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.1200k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4004",
            "sourceIpAddr": "$sourceip"
          }
        ]
      }
    ]
  }
}
EOF

open(BUILD,">build");
print BUILD "$str\n";
close BUILD;

}

sub buildSDJsonFile_1pro {
my $cs = shift;
my $sourceip = shift;
my $mc = shift;
my $desc = shift;

$str =  <<EOF;
{
  "id": "smtenant_0.smchannelsource.$cs",
  "name": "$cs",
  "type": "channelsources",
  "externalId": "/v2/channelsources/$cs",
  "properties": {
    "channelId": "$cs",
    "description": "$desc",
    "streamType": "ATS",
    "streams": [
      {
        "profileRef": "smtenant_0.smstreamprofile.300k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:4001",
            "sourceIpAddr": "$sourceip"
          }
        ]
      }
    ]
  }
}
EOF

open(BUILD,">build");
print BUILD "$str\n";
close BUILD;

}

sub usage {

print <<EOF;

The following parameters are required: 

i:	Name of Excel input file ( ex. $0 -i file.xlsx )
t:	Name of tab in the excel file to use
s:	SD Build only (1 SD Profile, UDP 4001 )
d:      Domain name (ex. mos.hcvlny.cv.net)
h:	Help message


EOF

exit;
}

sub create_input_file {

my $worksheet;
my $fname = shift;
my $tname = shift;
my $filename = 'input_file_parsed.txt';
my $haserrors = 0;
my %cs_list;

open(FILEN,">$filename") or die "Can't open $filename\n";

my $parser   = Spreadsheet::ParseExcel->new();
my $workbook = $parser->parse($fname);

if ( !defined $workbook ) {
    die $parser->error(), ".\n";
}

    $worksheet = $workbook->worksheet($tname);


        my ( $row_min, $row_max ) = $worksheet->row_range();
        $row_min++;


        for my $row ( $row_min .. $row_max ) {

                my $c_description = $worksheet->get_cell( $row, 0 );
                my $c_callsign    = $worksheet->get_cell( $row, 0 );
                my $c_sourceip    = $worksheet->get_cell( $row, 5 );
                my $c_type    = $worksheet->get_cell( $row, 4 );
                my $c_mcip    = $worksheet->get_cell( $row, 2 );
                next unless $c_callsign;

                my $desc = $c_description->unformatted();
                my $cs   = $c_callsign->unformatted();
                my $sip  = $c_sourceip->unformatted();
                my $type = $c_type->unformatted();
                my $mcip = $c_mcip->unformatted();

                $desc =~ s/,//g;

                print FILEN "$desc,$cs,$sip,$type,$mcip\n";

                # Error checking.  Must check for unique callsigns and ensure other fields are valid
                #
	            if ( exists $cs_list{$cs} ) {
		            print "$cs is NOT Unique\n";
                    $haserrors = 1;
	            } else {
		            $cs_list{$cs} = 1;
	            }
	
                if ( $mcip !~ /\d+\.\d+\.\d+\.\d+/ ) {
		            print "Invalid Multicast IP $mcip.  Please correct\n";
                    $haserrors = 1;
	            }
                if ( $sip !~ /\d+\.\d+\.\d+\.\d+/ ) {
                    $haserrors = 1;
		            print "Invalid Source IP $sip.  Please correct\n";
	            }
	
                # Check for invalid characters
	            if ( $cs =~ /_|\s+|\+|\!|\&/ ) {
                    $haserrors = 1;
                    print "Invalid character(s) found in callsign $cs.  Please correct\n";
                }
        }


close FILEN;

if ( $haserrors == 1 ) {
    print "Errors found in file.  Correct the errors and re-execute. NO CHANGES MADE..Exiting..\n";
    exit(2);
} else {
   return $filename;
}

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
