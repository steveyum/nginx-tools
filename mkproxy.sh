#!/bin/bash

NGINX="/etc/nginx"
SITESAVAIL="$NGINX/sites-available"
SITESENABLED="$NGINX/sites-enabled"
SSL="$NGINX/ssl"
WEBREPO="/var/www"
SSLCHALLENGE="/var/www/letsencrypt"
LIVECERT="/etc/letsencrypt/live"
EMAIL="steveyum@gmail.com"
FQDN=''
certdomains=''
hostlist=''
BACKEND=''

while test ${#} -gt 0
do
    case $1 in
        -b) shift
            BACKEND="$1"
            shift
            ;;
        *) hostlist+="$1 "
            shift
            ;;
    esac
done

# trim the possible leading/trailing space off $hostlist
hostlist=$(echo $hostlist | xargs)

if [ -z "$hostlist" ];
then
    echo -n "FQDN of proxy: "
    read hostlist
fi

# if there are multiple fqdn's, they're separated by space(s)
# so we cannot use $hostlist for naming purposes...
# so, we choose to use the last FQDN as virtual host name

for FQDN in $hostlist; do
    # a bad hack
    certdomains+="-d $FQDN "
    result=$(echo $FQDN | grep -P '(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}\.?$)')

    if [ -z "$result" ]; then
        echo "$FQDN is not a valid hostname"
        exit 1
    fi
done


if [ -z "$BACKEND" ]
then 
    echo -n "Backend to pass proxy: "
    read BACKEND
fi

echo -n "* creating virtual host $FQDN..."
sudo tee $SITESAVAIL/$FQDN <<EOF >/dev/null
server {
    listen 80;
    server_name $hostlist;

    location / {
        include snippets/proxy.conf;
        proxy_pass http://$BACKEND;
    }

    location /.well-known {
        root $SSLCHALLENGE; # local filesystem path
    }

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}

EOF
echo "done!"

# enable the site
echo -n "* enabling site $FQDN..."
sudo ln -s $SITESAVAIL/$FQDN $SITESENABLED/$FQDN
# make the web dir exists
if [ ! -d "$SSLCHALLENGE" ];
then
    sudo mkdir -p "$SSLCHALLENGE"
fi
echo "done!"

echo -n "* Checking nginx configuration..."
# is the configuration is correct?
result=$(sudo nginx -t 2>&1 >/dev/null)
if [[ -z $(echo $result | grep -P "ok|successful$") ]]; then
# if [ $? -ne 0 ]; then
    echo "error occurred in nginx configuration!"
    exit 1
fi
echo "done!"

echo -n "* reloading nginx..."
# nginx config checks out, so reload
sudo service nginx reload
echo "done!"

# make sure diffie hellman 2048 key's in its place
# openssl dhparam -out /etc/nginx/ssl/dhparam2048.pem 2048
echo -n "* checking for diffie hellman key..."
if [ ! -e $SSL/dhparam2048 ]
then
    echo "not found!"
    echo "***** creating diffie hellman key for the first time..."
    echo -n "***** get a cup of coffee or something, this will take a while..."
    sudo openssl dhparam -out /etc/nginx/ssl/dhparam2048.pem 2048
    echo "done!"
else
    echo "found!"
fi

# generate the SSL
echo -n "* Creating certificate..."
sudo certbot certonly -a webroot --webroot-path=$SSLCHALLENGE -m $EMAIL --agree-tos $certdomains
if [ $? -ne 0 ];
then
    echo "Certificate creation failed!"
    exit 1
fi
echo "done!"

# now define the https/encrypted virtual host server
# and append it to the original
sudo sed '3 a \ \ \ \ #force all traffic to https\n \ \ \ rewrite host -> whatever' test.txt
sudo tee -a $SITESAVAIL/$FQDN <<EOF >/dev/null
server {
    server_name $FQDN;
    listen 443 ssl;
    ssl on;
    ssl_certificate $LIVECERT/$FQDN/fullchain.pem;
    ssl_certificate_key $LIVECERT/$FQDN/privkey.pem;
    ssl_dhparam /etc/nginx/ssl/dhparam2048.pem;
    include snippets/ssl.conf;

    location / {
        include snippets/proxy.conf;
        proxy_pass http://$BACKEND; # notice we're proxy passing via http
    }
}
EOF

echo -n "* Checking nginx configuration one more time..."
# is the configuration is correct?
result=$(sudo nginx -t 2>&1 >/dev/null)
if [[ -z $(echo $result | grep -P "ok|successful$") ]]; then
# if [ $? -ne 0 ]; then
    echo "error occurred in nginx configuration!"
    exit 1
fi
echo "done!"

echo -n "* reloading nginx one more time..."
# nginx config checks out, so reload
sudo service nginx reload
echo "done!"

