#!/usr/bin/env python


import requests

# Pull streaming URL's from VMP

def getWorkflows(smip):
    
    url = "https://%s:7001/v1/assetWorkflows" % (smip)
    myResponse = requests.get(url,verify=False)
    if ( myResponse.status_code != 200 ):
        print "Could not get workflow names" 
        sys.exit(1)
    jData = json.loads(myResponse.content)
    print jData
    
    


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
