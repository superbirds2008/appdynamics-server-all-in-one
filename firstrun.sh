#!/bin/bash

#Get docker env timezone and set system timezone
echo "setting the correct local time"
echo $TZ > /etc/timezone
export DEBCONF_NONINTERACTIVE_SEEN=true DEBIAN_FRONTEND=noninteractive
dpkg-reconfigure tzdata

#Configure Appd for IP address given as environment variable
destfile=/root/response.varfile
if [ -f "$destfile" ]
then 
    appdserver="serverHostName=${SERVERIP}"
    echo "adding '$appdserver' to '$destfile'"
    echo "$appdserver" >> "$destfile"
fi

cd /config
if [ ! -z $VERSION ]; then
  echo "Manual version override:" $VERSION
  FILENAME="platform-setup-x64-linux-'$VERSION'.sh"
  echo "Filename: $FILENAME"
else
  #Check the latest version on appdynamics
  curl -s -L -o tmpout.json "https://download.appdynamics.com/download/downloadfile/?version=&apm=&os=linux&platform_admin_os=linux&events=&eum="
  VERSION=$(grep -oP '(\"version\"\:\")\K(.*?)(?=\"\,\")' tmpout.json)
  DOWNLOAD_PATH=$(grep -oP '(\"download_path\"\:\")\K(.*?)(?=\"\,\")' tmpout.json)
  FILENAME=$(grep -oP '(\"filename\"\:\")\K(.*?)(?=\"\,\")' tmpout.json)
  echo "Latest version on appdynamics is" $VERSION
  rm -f tmpout.json
fi

# check if enterprise console is installed
if [ -f /config/appdynamics/platform/platform-admin/bin/platform-admin.sh ]; then
  echo "Enterprise Console is installed"
else
  # check if user didn't downloaded latest Enterprise Console binary
  if [ ! -f /config/$FILENAME ]; then
    echo "Downloading AppDynamics Enterprise Console version '$VERSION'"
    TOKEN=$(curl -X POST -d '{"username": "'$AppdUser'","password": "'$AppdPass'","scopes": ["download"]}' https://identity.msrv.saas.appdynamics.com/v2.0/oauth/token | grep -oP '(\"access_token\"\:\s\")\K(.*?)(?=\"\,\s\")')
    curl -L -O -H "Authorization: Bearer ${TOKEN}" ${DOWNLOAD_PATH}
    echo "file downloaded"
  else
    echo "Found latest Enterprise Console '$FILENAME' in /config/ "
  fi
  # installing ent console
  echo "Installing Enterprise Console"
  chmod +x ./$FILENAME
  ./$FILENAME -q -varfile ~/response.varfile
fi

# check if Controller is installed
if [ -f /config/appdynamics/controller/controller/bin/controller.sh ]; then
  echo "Controller is installed"
else
  echo "Installing Controller and local database"
  cd /config/appdynamics/platform/platform-admin/bin
  ./platform-admin.sh create-platform --name my-platform --installation-dir /config/appdynamics/controller
  ./platform-admin.sh add-hosts --hosts localhost
  ./platform-admin.sh submit-job --service controller --job install --args controllerPrimaryHost=localhost controllerAdminUsername=admin controllerAdminPassword=appd controllerRootUserPassword=appd mysqlRootPassword=appd
fi

# check if Events Service is installed
if [ -f /config/appdynamics/controller/events-service/processor/bin/events-service.sh ]; then
  echo "Events Service is installed"
else
  echo "Installing Events Service"
  cd /config/appdynamics/platform/platform-admin/bin
  ./platform-admin.sh install-events-service  --profile dev --hosts localhost
fi

# check if EUM Server is installed
if [ -f /config/appdynamics/EUM/eum-processor/bin/eum.sh ]; then
  echo "EUM Server is installed"
else
  # Check latest EUM server version
  cd /config
  echo "Checking EUM server version"
  #Check the latest version on appdynamics
  curl -s -L -o tmpout.json "https://download.appdynamics.com/download/downloadfile/?version=&apm=&os=linux&platform_admin_os=&events=&eum=linux"
  EUMDOWNLOAD_PATH=$(grep -oP '(?:\"download_path\"\:\")(?!.*dmg)\K(.*?)(?=\"\,\")' tmpout.json)
  EUMFILENAME=$(grep -oP '(?:\"filename\"\:\")(?!.*dmg)\K(.*?)(?=\"\,\")' tmpout.json)
  rm -f tmpout.json
  # check if user downloaded latest EUM server binary
  if [ -f /config/$EUMFILENAME ]; then
    echo "Found latest EUM Server '$FILENAME' in /config/ "
  else
    echo "Didn't find '$FILENAME' in /config/ - downloading"
	NEWTOKEN=$(curl -X POST -d '{"username": "'$AppdUser'","password": "'$AppdPass'","scopes": ["download"]}' https://identity.msrv.saas.appdynamics.com/v2.0/oauth/token | grep -oP '(\"access_token\"\:\s\")\K(.*?)(?=\"\,\s\")')
    curl -L -O -H "Authorization: Bearer ${NEWTOKEN}" ${EUMDOWNLOAD_PATH}
    echo "file downloaded"
  fi
  chmod +x ./$EUMFILENAME
  echo "Installing EUM server"
  ./$EUMFILENAME -q -varfile ~/response-eum.varfile
fi

echo "Setting correct permissions"
chown -R nobody:users /config

# Start the AppDynamics Services
echo "Starting AppDynamics Services"
cd /config/appdynamics/platform/platform-admin/bin
echo "Starting Enterprise Console"
./platform-admin.sh start-platform-admin
echo "Starting Controller with DB"
./platform-admin.sh start-controller-appserver --with-db
echo "Starting Events Service"
./platform-admin.sh start-events-service
echo "Starting EUM Server"
cd /config/appdynamics/EUM/eum-processor/
./bin/eum.sh start

echo "System Started"
