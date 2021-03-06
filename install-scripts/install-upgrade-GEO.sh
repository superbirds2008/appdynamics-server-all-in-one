#!/bin/bash

# initialize variables
TOMCAT_FILE=$APPD_INSTALL_DIR/tomcat/bin/startup.sh
cd $APPD_INSTALL_DIR

if [ ! -f "$TOMCAT_FILE" ]; then
	TOMCAT_INSTALL_UPGRADE_FILE=$APPD_SCRIPTS_DIR/install-scripts/install-upgrade-tomcat.sh
	if [ -f "$TOMCAT_INSTALL_UPGRADE_FILE" ]; then
		chmod +x $TOMCAT_INSTALL_UPGRADE_FILE
		bash $TOMCAT_INSTALL_UPGRADE_FILE
	else
		echo "Tomcat install file not found here - $TOMCAT_INSTALL_UPGRADE_FILE"
	fi
else
	echo "Tomcat already installed"
fi 

if [ ! -z $GEO_FILENAME ]; then
	echo "Manual Override - Attempting to use $GEO_FILENAME for custom geo server installation..."
	if [ -f $GEO_FILENAME ]; then
		FILENAME=$GEO_FILENAME
	else
		echo "Cannot find file: $GEO_FILENAME"
	fi
else
	# Use manual version or latest available from AppDynamics
	if [ ! -z $VERSION ]; then
		echo "Manual version override:" $VERSION
		#Check for valid version on appdynamics
		curl -s -L -o tmpout.json "https://download.appdynamics.com/download/downloadfile/?version=$VERSION&eum=geoserver"
		DOWNLOAD_PATH=$(grep -oP '(?:filename\"\:\"GeoServer-\d+\.\d+\.\d+\.\d+\.zip[\s\S]+?(?=http))\K(.*?)(?=\"\,)' tmpout.json)
		FILENAME=$(grep -oP '(?:filename\"\:\")\K(GeoServer-\d+\.\d+\.\d+\.\d+\.zip)(?=\"\,)' tmpout.json)
		echo "Filename expected: $FILENAME"
	else
		#Check the latest version on appdynamics
		curl -s -L -o tmpout.json "https://download.appdynamics.com/download/downloadfile/?eum=geoserver"
		VERSION=$(grep -oP '(?:filename\"\:\"GeoServer-\d+\.\d+\.\d+\.\d+\.zip[\s\S]+?(?=version))(?:version\"\:\")\K(.*?)(?=\"\,)' tmpout.json)
		DOWNLOAD_PATH=$(grep -oP '(?:filename\"\:\"GeoServer-\d+\.\d+\.\d+\.\d+\.zip[\s\S]+?(?=http))\K(.*?)(?=\"\,)' tmpout.json)
		FILENAME=$(grep -oP '(?:filename\"\:\")\K(GeoServer-\d+\.\d+\.\d+\.\d+\.zip)(?=\"\,)' tmpout.json)
		echo "Latest version on appdynamics is" $VERSION
	fi
	rm -f tmpout.json
fi

# Check if Geo Server is already installed
GEO_DIR=$APPD_INSTALL_DIR/tomcat/webapps
GEO_FILE=$GEO_DIR/geo/geo-ip-mappings.xml
if [ ! -f "$GEO_FILE" ]; then
	# check if user didn't downloaded latest Enterprise Console binary
	if [ ! -f /config/$FILENAME ]; then
		echo "Didn't find '$FILENAME' in '$APPD_INSTALL_DIR' - downloading instead"
		echo "Downloading Customer Geo Server version '$VERSION'"
		TOKEN=$(curl -X POST -d '{"username": "'$AppdUser'","password": "'$AppdPass'","scopes": ["download"]}' https://identity.msrv.saas.appdynamics.com/v2.0/oauth/token | grep -oP '(\"access_token\"\:\s\")\K(.*?)(?=\"\,\s\")')
		curl -L -O -H "Authorization: Bearer ${TOKEN}" ${DOWNLOAD_PATH}
		echo "file downloaded"
	else
		echo "Found Custom Geo Server version:'$VERSION' - '$FILENAME' in '$APPD_INSTALL_DIR' "
	fi
	
	echo "Unzipping: $FILENAME"
	unzip -oq $APPD_INSTALL_DIR/$FILENAME GeoServer/geo/* -d $GEO_DIR
	unzip -oq $APPD_INSTALL_DIR/$FILENAME GeoServer/README.txt -d $GEO_DIR
	unzip -oq $APPD_INSTALL_DIR/$FILENAME GeoServer/schema.xsd -d $GEO_DIR
	mv $GEO_DIR/GeoServer/README.txt $GEO_DIR/GeoServer/geo/
	mv $GEO_DIR/GeoServer/schema.xsd $GEO_DIR/GeoServer/geo/
	mv $GEO_DIR/GeoServer/geo/ $GEO_DIR/
	rm -r $GEO_DIR/GeoServer/
	echo "Unzip complete"
	# let the user cleanup binaries
	# rm $APPD_INSTALL_DIR/$FILENAME
else
	echo "Custom Geo Server Already Installed"
fi 