!#/bin/sh

# Set some variables
HOST=$(hostname)

# auto set email root@ hostname (forwards based on cpanel configuration)
CONTACT_USER='root@'
CONTACT_EMAIL=("${CONTACT_USER}""${HOST}")

# Install certbot & attempt unattended certbot installation 
sudo dnf install certbot -y && certbot certonly --standalone -d $HOST -n -m $CONTACT_EMAIL --agree-tos

# create python script
cat  <<EOF > /usr/local/bin/whmcert.py
#!/bin/env python

import sys, urllib, re, subprocess
from subprocess import call
from urllib.parse import quote

if len(sys.argv) < 2:
    print("The hostname must be specified.")
    exit(1)

hostname = sys.argv[1]
hostname_pattern = re.compile("^[a-z0-9\.-]+$", re.IGNORECASE)

if not hostname_pattern.match(hostname):
    print("The hostname contains invalid characters.")
    exit(1)

file_cert = open("/etc/letsencrypt/live/" + hostname + "/cert.pem")
file_privkey = open("/etc/letsencrypt/live/" + hostname + "/privkey.pem")
file_chain = open("/etc/letsencrypt/live/" + hostname + "/chain.pem")

cert = file_cert.read()
privkey = file_privkey.read()
chain = file_chain.read()

file_cert.close
file_privkey.close
file_chain.close

cert = urllib.parse.quote(cert)
privkey = urllib.parse.quote(privkey)
chain = urllib.parse.quote(chain)

call(["/usr/sbin/whmapi1", "install_service_ssl_certificate", "service=cpanel", "crt=" + cert, "key=" + privkey, "cabundle=" + chain])
call(["systemctl", "restart", "cpanel"])
EOF

# Set permissions
chmod 0700 /usr/local/bin/whmcert.py

# Add cron to run script for SSL renewal 
(crontab -l ; echo "0 0 * * 1 /usr/bin/certbot renew --quiet --post-hook '/usr/local/bin/whmcert.py $HOST'")| crontab -
