#!/bin/bash

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
SITE="${!#}"

## figure out the base site URL to contruct the URL for the login page
## remove trailing slash
BASESITE=$(echo ${SITE%/})
while true
do
  SUB=$(echo ${BASESITE##*/})
  HTTPCODE=$(curl -s --output /dev/null -w "%{http_code}\n" ${BASESITE}/update.php)
  if [[ "${HTTPCODE}" != 403 && "${HTTPCODE}" != 404 ]]
  then
    break
  fi
  BASESITE=$(echo ${BASESITE} | sed "s/\/${SUB}//")
done

LOGINURL="${BASESITE}/user"
POSTVARS="name=${DUSER}&pass=${DPASS}&form_id=user_login&op=Log+in"

LOGFILE=$(siege -C | grep "log file" | awk -F: '{print $2}' | sed 's# ##g')
SIEGELOGINURL="
login-url = ${LOGINURL} POST ${POSTVARS}
"

cat "${SIEGERC}" > ${SIEGERCFILE}
echo "${SIEGELOGINURL}" >> ${SIEGERCFILE}

echo "siege -R ${SIEGERCFILE} $@"
siege -R ${SIEGERCFILE} $@

rm ${SIEGERCFILE}
