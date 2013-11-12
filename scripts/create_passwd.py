#!/usr/bin/env python3
### WARNING ###
# requires Python >= 3.3

import sys, crypt, getpass;

# this script generate a password using salted SHA512 whitch is the default on debian wheezy

cleartext = getpass.getpass("Password:")
cleartext2 = getpass.getpass("Again:")
if cleartext2 != cleartext:
	print ('Not matched!')
	sys.exit(1)
	
salt = crypt.mksalt(crypt.METHOD_SHA512)
print (crypt.crypt(cleartext, salt))

