#!/usr/bin/env python

import dns.resolver
import requests
import sys
import getopt
import socket
import json

# Pull streaming URL's from VMP

def getWorkflows(smip):
    wflist = []
    url = "https://%s:7001/v1/assetWorkflows" % (smip)
    myResponse = requests.get(url,verify=False)
    if ( myResponse.status_code != 200 ):
        print "Could not get workflow names" 
        sys.exit(1)

    jData = json.loads(myResponse.content)

    for wf in jData:
        wflist.extend([wf['workflowId']])

    return wflist
    
def getsmip(domain):
    
    try:
        answers = dns.resolver.query('rest.pm.mos.%s' % domain)
    except: 
        print "Unable to determine service manager IP address for domain %s" % domain 
        sys.exit(1)

    for rdata in answers:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((str(rdata),7001))
        if result == 0:
               return rdata

def getContentIDs(smip,wf):
    cidlist = []
    url = "https://%s:7001/v1/assetWorkflows/%s/assets" % (smip,wf)
        myResponse = requests.get(url,verify=False)
    
    if ( myResponse.status_code != 200 ):
               print "Could not get workflow names" 
            sys.exit(1)

    jData = json.loads(myResponse.content)
    
    for cid in jData:
            cidlist.extend([cid['contentId']])
    
        return cidlist
    
def getPubUrl(smip,wf):
    variantlist = []
    url = "https://%s:7001/v1/assetWorkflows/%s" % (smip,wf)
        myResponse = requests.get(url,verify=False)
    
    if ( myResponse.status_code != 200 ):
               print "Could not get variant names/URLs" 
            sys.exit(1)

    jData = json.loads(myResponse.content)
    for pt in jData['publishTemplates']:
            for variants in pt['variants']:
            url  = variants['publishUrl']
            name = variants['name']
            variantlist.append([url,name])
        
    return variantlist 

def main(argv):
    try:
        opts,args = getopt.getopt(argv,"d:",["domain="])
    except getopt.GetoptError as err:
        print str(err)
        sys.exit(2)
    else:
        for opt,arg in opts:
            if opt == '-h':
                print sys.argv[0] + " -d|--domain <domain name>"
                sys.exit(1)
            elif opt in ( "-d", "--domain"):
                domain = arg
            else:
                assert False, "Unknown"
                sys.exit(2)

    if len(argv) == 0:
        print "Usage: " +  sys.argv[0] + " -d|--domain <domain name>. No arguments given"
        sys.exit(1)

    try:
        domain
    except NameError:
        print "Domain not specified (-d or --domain)"
        sys.exit(1)

    smip = getsmip(domain)
    if smip is None:
        print "Could not determine service manager IP.  Exiting"
        sys.exit(1)
    
    wf = getWorkflows(smip)
    
    for wfname in wf:
        contentIDs = getContentIDs(smip,wfname)    
        variants   = getPubUrl(smip,wfname)
        
        for vals in contentIDs:
            for urls in variants:
                modurl = urls[0].replace("{CONTENT_ID}",vals)
                print "%s,%s,%s,%s" % (vals,wfname,modurl,urls[1])

    
    
if __name__ == '__main__':
    main(sys.argv[1:])
