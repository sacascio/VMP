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

# Script to restart services from CLI
# Prepared by Salvatore Cascio (Cisco)
# March 29, 2017
# Version 1
# Assume: 
#	  1) Shared SSH keys between this system and the PAM nodes using the admin user
#	  2) dnsresolver python module installed
	  


def getPayloadJSON (smip,workflow,service) :
	url = "https://%s:7001/v1/assetWorkflows/%s/assets/%s" % (smip,workflow,service)
	myResponse = requests.get(url,verify=False)
	if ( myResponse.status_code != 200 ):
		print "service %s not found in %s workflow" % (service,workflow)
		sys.exit(1)
	jData = json.loads(myResponse.content)
	del jData['status']
	del jData['output']
	jData['restart'] = True
	return jData

def getsmip(domain):
	
	try:
		answers = dns.resolver.query('rest.pm.mos.%s' % domain)
	except: 
		print "Unable to determine service manager IP address for domain %s" % domain 
		sys.exit(1)

	for rdata in answers:
		sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		result = sock.connect_ex((str(rdata),7001))
		if result == 0:
   			return rdata

def getvmptoken(smip):
	cmd = "cat /etc/opt/cisco/mos/public/token.json"

	ssh = subprocess.Popen(["ssh", "%s" % smip, cmd],
                       shell=False,
                       stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
	result = ssh.stdout.readlines()
	string = ''.join(result)
	jData = json.loads(string)
	return jData['tokenMap']['defaultToken']['name']

def getuser():
	return(pwd.getpwuid( os.getuid() ).pw_name)

def main(argv):
	user = getuser()

	if ( user != 'admin' ):
		print "Script must be run as the admin user"
		sys.exit(1)
	
	try:
		opts,args = getopt.getopt(argv,"d:s:hw:",["domain=","service=","help","workflow="])
	except getopt.GetoptError as err:
		print str(err)
		sys.exit(2)
	else:
		for opt,arg in opts:
			if opt == '-h':
				print sys.argv[0] + " -d|--domain <domain name> -s|--service <servicename>"
				sys.exit(1)
			elif opt in ( "-d", "--domain"):
				domain = arg
			elif opt in ( "-s", "--service"):
				service = arg
			elif opt in ( "-w", "--workflow"):
				workflow = arg
			else:
				assert False, "Unknown"
				sys.exit(2)

	if len(argv) == 0:
		print "Usage: " +  sys.argv[0] + " -d|--domain <domain name> -s|--service <servicename> | -w|--workflow <workflow name>.  No arguments given"
		sys.exit(1)

	try:
		domain
	except NameError:
		print "Domain not specified (-d or --domain)"
		sys.exit(1)
	
	try:
		service
	except NameError:
		print "Service not specified (-s or --service)"
		sys.exit(1)
	
	try:
		workflow
	except NameError:
		print "Workflow not specified (-w or --workflow)"
		sys.exit(1)
	
	# Get SM IP used to query
	smip = getsmip(domain)

	# Squelch SSL warnings for no certificate
	requests.packages.urllib3.disable_warnings()

	# Get Token
	token = getvmptoken(smip)
	
	payloadjson = getPayloadJSON(smip,workflow,service)
	
	headers = {'Content-Type' : 'application/json', 'Authorization' : 'Bearer %s' % token}
	
	url = "https://%s:7001/v1/assetWorkflows/%s/assets/%s" % (smip,workflow,service)
	
	myResponse = requests.put(url,verify=False,json=payloadjson,headers=headers)

	print (myResponse.content)

if __name__ == '__main__':
	main(sys.argv[1:])
