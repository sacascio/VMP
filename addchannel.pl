#!/usr/bin/perl -w

use strict;
use Getopt::Std;
use Spreadsheet::ParseExcel;
# SDL Version 2 
my $callsign;
my $sourceip;
my $type;
my $mcip;
my $str;
my %opts;
my $fname;
my $tname;
my %cs_list;
my $retcode;
my $description;
my $ss_cs;
my $sd_only_1pro = 0;

getopts('hi:t:s', \%opts);

usage() if ( ! %opts );
usage() if ( ! $opts{t} || !$opts{i} );
usage() if ( $opts{h} );

$fname = $opts{i};
$tname = $opts{t};

if ( $opts{s} ) {
	$sd_only_1pro = 1;
}


$fname = create_input_file($fname,$tname);

open(FILE,$fname) or die "Can't open $fname\n";
open(ELOG,">elog.txt") or die "Can't open elog.txt\n";
open(NEWCS,">callsigns") or die "Can't open callsigns\n";
open(CSMAP,">csmapping") or die "Can't open csmapping\n";

while(<FILE>) {
	chomp($_);
	($description,$callsign,$sourceip,$type,$mcip) = split(/,/, $_);

	# Replace underscore with dash in callsign
	$callsign =~ s/_/-/g;
	$callsign =~ s/\s+//g;
	$callsign =~ s/\+/-PLUS/g;
	$callsign =~ s/\!//g;
	$callsign =~ s/\&//g;
	$ss_cs = $callsign;

	if ( exists $cs_list{$callsign} ) {
		$callsign = getuniquecs($callsign);
	} else {
		$cs_list{$callsign} = 1;
	}

	# Print out NEW callsign value - might be equal to callsign provided in file
	# This is needed so that we can map the old callsign to new callsign values in the provided spreadsheet.
	
	print CSMAP "$ss_cs,$callsign\n";

	$type = uc($type);

	if ( $mcip !~ /\d+\.\d+\.\d+\.\d+/ or $sourceip !~ /\d+\.\d+\.\d+\.\d+/ ) {
		print ELOG "$_\n";
		next;
	}

    if ( $sd_only_1pro == 0 ) {
	#if ( $type eq 'HD' ) { 
	if ( $type =~ /9004/ ) { 
		buildSDJsonFile($callsign,$sourceip,$mcip,$description);
	} else {
		buildHDJsonFile($callsign,$sourceip,$mcip,$description);
	}
    } else {
	buildSDJsonFile_1pro($callsign,$sourceip,$mcip,$description);
    }
	

	## Add channel to V2P ##
	$retcode = addchannel($callsign);

	
	if ( $retcode != 200 ) {
		print ELOG "CHANNEL CREATION FAILED: $_\n";
	} else {
		print NEWCS "$callsign\n";
	}
		
	## Delete JSON build File	
	unlink("build");

}		

close FILE;
close ELOG;
close NEWCS;
close CSMAP;

sub addchannel {
# Token following the word Bearer comes from the PAM in /etc/opt/cisco/mos/public/token.json
my $cs  = shift;
`curl -w "%{http_code}" -o /dev/null -k -v -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2"  https://service-mgr.mos.hcvlny.cv.net:8043/v2/channelsources/$cs -H Content-Type:application/json -X POST -d \@build > /dev/null 2>&1`;
my $res = `curl -w "%{http_code}" -o /dev/null -k -v -H "Authorization: Bearer c49d2ad386d45c41e5c1ca2bbfe531dab7136601d3cc01e3434b97b965118ac2"  https://service-mgr.mos.hcvlny.cv.net:8043/v2/channelsources/$cs -H Content-Type:application/json -X PUT -d \@build 2>/dev/null`;


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
            "sourceUrl": "udp://$mc:9001",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.600k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:9002",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.1000k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:9003",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.1500k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:9004",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.2200k",
 	"sources": [
          {
            "sourceUrl": "udp://$mc:9005",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.4000k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:9006",
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
            "sourceUrl": "udp://$mc:9001",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.625k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:9002",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.925k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:9003",
            "sourceIpAddr": "$sourceip"
          }
        ]
      },
      {
        "profileRef": "smtenant_0.smstreamprofile.1200k",
        "sources": [
          {
            "sourceUrl": "udp://$mc:9004",
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
            "sourceUrl": "udp://$mc:9001",
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

The following parameters are required: i

i:	Name of Excel 2007 input file ( ex. $0 -i file.xls )
t:	Name of tab in the excel file to use
s:	SD Build only (1 SD Profile, UDP 9001 )
h:	Help message


EOF

exit;
}

sub getuniquecs {
my $cs = shift;
my $v = 2;
my $newcs = $cs;

        while ( exists $cs_list{$newcs} ) {
                $newcs = $cs . "-" . $v;
                $v++;
        }

        $cs_list{$newcs} = 1;
        return $newcs;

}

sub create_input_file {

my $worksheet;
my $fname = shift;
my $tname = shift;
my $filename = 'input_file_parsed.txt';


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
                my $c_callsign    = $worksheet->get_cell( $row, 1 );
                my $c_sourceip    = $worksheet->get_cell( $row, 4 );
                my $c_type    = $worksheet->get_cell( $row, 3 );
                my $c_mcip    = $worksheet->get_cell( $row, 2 );
                next unless $c_callsign;

                my $desc = $c_description->unformatted();
                my $cs   = $c_callsign->unformatted();
                my $sip  = $c_sourceip->unformatted();
                my $type = $c_type->unformatted();
                my $mcip = $c_mcip->unformatted();

                $desc =~ s/,//g;

                print FILEN "$desc,$cs,$sip,$type,$mcip\n";
        }


close FILEN;

return $filename;

}
