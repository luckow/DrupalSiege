#!/bin/bash

while getopts ":f:" OPT
do
  case $OPT in
    f ) URLFILE="$OPTARG" ;;
  esac
done

## prompt for drupal login. Comment this out and fill define DBUSER and DBPASS below to skip this step....
read -p "Drupal Login: " DUSER;
stty -echo 
read -p "Password: " DPASS;
stty echo
#DUSER=''
#DPASS=''

## url encode the password
DPASS=$(echo -n "${DPASS}" | perl -pe 's/([^-_.~A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg')

## create a temp file to hold the siegerc
SIEGERCFILE=$(mktemp /tmp/$(basename $0).XXXXXX) || exit 1

# I'm working with many source-files from apache-logs, and the urls are not always wellformed - I'll give 5 tries to figure out the correct basesite url
TRIES=1

while true
do

  #echo " > TRIES is ${TRIES}"

  if [[ -n "$URLFILE" ]]
  then
    RAWSITE="http://$(grep -Ei 'http(s)?://' $URLFILE | cut -d "/" -f 3 | head -$TRIES | tail -1)"
    # for debugging purposes
    echo " > RAW: ${RAWSITE}"
    SITE="${RAWSITE#}"
  else
    SITE="${!#}"
  fi

  #echo " > rawsite: ${RAWSITE}"
  #echo " > site: ${SITE}"

  ## figure out the base site URL to contruct the URL for the login page
  ## remove trailing slash
  BASESITE=$(echo ${SITE%/})

  # OK, I give up, let the user enter the correct basesite url
  if [[ "${TRIES}" == 5 ]] 
  then
    echo " >>>>> ERROR! <<<<< 5 tries, failed! Bombing out..."
    read -p " > Please enter the full baseurl (e.g. http://abc.dk): " BASESITE;
    stty echo 
    BASESITE=$(echo -n "${BASESITE}")
  fi

  SUB=$(echo ${BASESITE##*/})x
  HTTPCODE=$(curl -s -k --output /dev/null -w "%{http_code}\n" ${BASESITE}/install.php)

  if [[ "${HTTPCODE}" != 200 ]] 
  then
    echo " >>>>> WARNING (${TRIES}) <<<<< WRONG BASESITE URL: ${BASESITE}/install.php"
    echo " >>>>> WARNING (${TRIES}) <<<<< URL has an unexpected HTTP CODE (${HTTPCODE}), trying the next (looking for 200 OK)"
    TRIES=`expr $TRIES + 1`
  fi

  if [[ "${HTTPCODE}" == 200 ]] 
  then
    echo " > YAY! install.php found at ${BASESITE}/install.php"
    break
  fi

  BASESITE=$(echo ${BASESITE} | sed "s/\/${SUB}//")
done

echo " > All variables set, preparing to launch Siege..."

LOGINURL="${BASESITE}/user"
POSTVARS="name=${DUSER}&pass=${DPASS}&form_id=user_login&op=Log+in"

LOGFILE=$(siege -C | grep "log file" | awk -F: '{print $2}' | sed 's# ##g')
SIEGERC="$(siege -C | grep "resource file:" | awk -F: '{print $2}' | sed 's# ##g')"
SIEGELOGINURL="
login-url = ${LOGINURL} POST ${POSTVARS}
"

cat "${SIEGERC}" > ${SIEGERCFILE}
echo "${SIEGELOGINURL}" >> ${SIEGERCFILE}

echo "siege -R ${SIEGERCFILE} $@"
siege -R ${SIEGERCFILE} $@

rm ${SIEGERCFILE}
