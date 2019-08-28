#!/bin/bash

NGINX="/etc/nginx"
AVAIL="$NGINX/sites-available"
ENABL="$NGINX/sites-enabled"

function _is_available() {
    local domain="$1"
    if [ -e "$AVAIL/$domain" ]
    then
        return 0
    else
        return 1
    fi
}

function _is_enabled() {
    local domain="$1"

    if _is_available $domain && [ -e "$ENABL/$domain" ]
    then
        return 0
    else
        return 1
    fi
}

function _check_domain() {
    local domain="$1"
    if [ -z "$domain" ]
    then
        echo "no domain specified"
        exit 1
    else
        return 0
    fi
}
function _check_status() {
    if [ $? -gt 0 ]
    then
        echo "Failed"
    else
        echo "Success"
    fi
}
function _make_exit() {
    _check_status
    exit
}
return
case "$1" in
    test)  result=$(sudo nginx -t 2>&1 >/dev/null)
            if [[ -z $(echo $result | grep -P "ok|successful$") ]]; then
                echo "error occurred in nginx configuration!"
                exit 1
            else
                echo "Nginx configuration is ok."
            fi
            ;;
    edit)   domain="$2"
            _check_domain $domain
            if _is_available $domain
            then
                vi $AVAIL/$domain
            else
                echo "$domain does not exist."
            fi
            ;;
    enable) domain="$2"
            _check_domain $domain
            if _is_enabled $domain
            then
                echo "$domain is already enabled"
            else
                if _is_available $domain
                then
                    sudo ln -s $AVAIL/$domain $ENABL/$domain
                    _check_status
                fi
            fi
            ;;
    disable) domain="$2"
            _check_domain $domain
            if _is_enabled $domain
            then
                sudo rm -rf $ENABL/$domain
                _check_status
            fi
            ;;
    delete) domain="$2"
            _check_domain $domain
            if _is_available $domain
            then
                sudo rm -rf $AVAIL/$domain
                _check_status
            fi

            if _is_enabled $domain
            then
                sudo rm -rf $ENSBL/$domain
                _check_status
            fi
            ;;
