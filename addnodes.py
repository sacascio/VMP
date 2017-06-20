#!/usr/bin/env python
import requests
import json
import socket
import getopt
import sys
import subprocess
import os
import pwd
import dns.resolver


# Script to add nodes to VMP
# Prepared by Salvatore Cascio (Cisco)
# June 16, 2017
# Version 1
##

def getJSONPayload(node,mgmt,din,dout,wtype,desc,aic):
   
    jData = {}
    jData["name"] = node
    jData["id"]   = "smregion_0.smnode.%s" % node
    jData["type"] = "nodes"        
    jData["externalId"] = "/v2/regions/region-0/nodes/%s" % node
    jData["properties"] = { "description" : desc, "adminState" :"inservice", "zoneRef" : "smtenant_system.smzone.zone-1", "aic" : aic }
    jData["properties"].update({ "image" : { "imgTag" : wtype, "personality" : "worker", "version" : "2.8"} })
    jData["properties"].update({"interfaces" : [{"type" : "mgmt","inet" : mgmt},{"type" : "data-in","inet" : din},{"type" : "data-out","inet" : dout}]})
   
    return jData     
	             

def getvmptoken(smip):
    cmd = "cat /etc/opt/cisco/mos/public/token.json"
    user = 'admin@%s' % smip
    ssh = subprocess.Popen(["ssh", "%s" % user, cmd],
                       shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
    result = ssh.stdout.readlines()
    string = ''.join(result)
    jData = json.loads(string)
    return jData['tokenMap']['defaultToken']['name']      

def getsmip(domain):
    
    try:
        answers = dns.resolver.query('ui.%s' % domain)
    except: 
        print "Unable to determine service manager IP address for domain %s" % domain 
        sys.exit(1)

    return answers[0]
   
def createNode(url,jData,headers):
    myResponse = requests.post(url,verify=False,json=jData,headers=headers)
    return myResponse.status_code
    
def main(argv):
 
    try:
        opts,args = getopt.getopt(argv,"f:d:h",["file=","domain=","help"])
    except getopt.GetoptError as err:
        print str(err)
        sys.exit(2)
    else:
        for opt,arg in opts:
            if opt == '-h':
                print sys.argv[0] + " -f|--file <filename> -d|--domain <domain name>"
                sys.exit(1)
            elif opt in ( "-f", "--file"):
                filename = arg
            elif opt in ( "-d", "--domain"):
                domain = arg
            else:
                assert False, "Unknown"
                sys.exit(2)

    if len(argv) == 0:
        print "Usage: " +  sys.argv[0] + " -f|--file <file name> -d|--domain <domain name>.  No arguments given"
        sys.exit(1)

    try:
        filename
    except NameError:
        print "Filename not specified (-f or --file)"
        sys.exit(1)
        
    try:
        domain
    except NameError:
        print "Domain name not specified (-d or --domain)"
        sys.exit(1)
    
    
    # Get SM IP used to query
    smip = getsmip(domain)
    if smip is None:
        print "Could not determine service manager IP.  Exiting"
        sys.exit(1)

    # Squelch SSL warnings for no certificate
    requests.packages.urllib3.disable_warnings()

    # Get Token
    token = getvmptoken(smip)
    
    
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            entry = line.split(',')
            node = entry[0]
            mgmt = entry[1]
            din  = entry[2]
            dout = entry[3]
            wtype = entry[4]
            desc = entry[5]
	    aic  = entry[6]
            
            headers = {'Content-Type' : 'application/json', 'Authorization' : 'Bearer %s' % token}
    	    url = "https://%s:8043/v2/regions/region-0/nodes/%s" % (smip,node)
            jData = getJSONPayload(node,mgmt,din,dout,wtype,desc,aic)
            status = createNode(url,jData,headers)

	    if ( status == 200 ):
		print "OK: Node %s created" % node
	    else:
		print "ERROR: Node %s NOT created" % node

if __name__ == '__main__':
    main(sys.argv[1:])
