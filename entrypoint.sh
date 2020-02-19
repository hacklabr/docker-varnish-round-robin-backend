#!/bin/sh
set -e

if [ -z "$VCL_FILE" ]; then 
    VCL_FILE="/etc/varnish/empty.vcl"; 
fi

nodejs /daemon.js &

while [ ! -f /etc/varnish/backends.vcl ]
do
  sleep .2
done

varnishd -F -f $VCL_FILE