#!/bin/bash

# ============================================================
#   Apache Tomcat Installation Script for Ubuntu 22.04 LTS
#   - Uses: dlcdn.apache.org (reliable CDN mirror)
#   - Version: Auto-fetches latest 10.1.x
#   - Credentials: tomcat / tomcat
#   - Manager & Host-Manager open to all IPs
# ============================================================

set -e  # Exit immediately on any error

TOMCAT_VERSION="10.1.53"   # Latest stable as of March 2026
TOMCAT_MAJOR="10"
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
INSTALL_DIR="/opt/tomcat"
JAVA_PACKAGE="openjdk-17-jdk"
TOMCAT_ADMIN_USER="tomcat"
TOMCAT_ADMIN_PASS="tomcat"

# ------------------------------------------------------------------
# Primary CDN + Archive fallback URLs
# ------------------------------------------------------------------
PRIMARY_URL="https://dlcdn.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
FALLBACK_URL="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"

echo "====> Step 1: Updating system packages..."
sudo apt update -y && sudo apt upgrade -y

echo "====> Step 2: Installing dependencies (Java + wget + curl)..."
sudo apt install -y "$JAVA_PACKAGE" wget curl

echo "====> Verifying Java installation..."
java -version

echo "====> Step 3: Creating dedicated Tomcat system user and group..."
sudo groupadd --system "$TOMCAT_GROUP" 2>/dev/null || echo "  [INFO] Group '$TOMCAT_GROUP' already exists."
sudo useradd -s /bin/false -g "$TOMCAT_GROUP" -d "$INSTALL_DIR" "$TOMCAT_USER" 2>/dev/null || echo "  [INFO] User '$TOMCAT_USER' already exists."

echo "====> Step 4: Downloading Apache Tomcat ${TOMCAT_VERSION}..."
echo "  Trying primary CDN: $PRIMARY_URL"

if wget --timeout=30 -q "$PRIMARY_URL" -O /tmp/apache-tomcat.tar.gz; then
    echo "  [OK] Downloaded from primary CDN."
else
    echo "  [WARN] Primary CDN failed. Trying Apache Archive mirror..."
    if wget --timeout=60 -q "$FALLBACK_URL" -O /tmp/apache-tomcat.tar.gz; then
        echo "  [OK] Downloaded from Apache Archive."
    else
        echo "  [ERROR] Both download sources failed. Check your internet connection."
        exit 1
    fi
fi

echo "====> Verifying downloaded file..."
if [ ! -s /tmp/apache-tomcat.tar.gz ]; then
    echo "  [ERROR] Downloaded file is empty or missing!"
    exit 1
fi
echo "  [OK] File looks valid: $(du -sh /tmp/apache-tomcat.tar.gz | cut -f1)"

echo "====> Step 5: Extracting Tomcat to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf /tmp/apache-tomcat.tar.gz -C "$INSTALL_DIR" --strip-components=1
rm -f /tmp/apache-tomcat.tar.gz
echo "  [OK] Extracted successfully."

echo "====> Step 6: Setting ownership and permissions..."
sudo chown -R "$TOMCAT_USER":"$TOMCAT_GROUP" "$INSTALL_DIR"
sudo chmod -R 750 "$INSTALL_DIR"
sudo chmod -R u+x "$INSTALL_DIR/bin"

# ----------------------------------------------------------------
echo "====> Step 7: Configuring tomcat-users.xml (credentials)..."
# ----------------------------------------------------------------
sudo tee "$INSTALL_DIR/conf/tomcat-users.xml" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">

  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>

  <!-- Admin credentials: tomcat / tomcat -->
  <user username="${TOMCAT_ADMIN_USER}"
        password="${TOMCAT_ADMIN_PASS}"
        roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>

</tomcat-users>
EOF
echo "  [OK] tomcat-users.xml configured."

# ----------------------------------------------------------------
echo "====> Step 8: Allowing Manager access from ANY IP..."
# ----------------------------------------------------------------
sudo mkdir -p "$INSTALL_DIR/webapps/manager/META-INF"
sudo tee "$INSTALL_DIR/webapps/manager/META-INF/context.xml" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!-- IP restriction removed: accessible from any IP -->
</Context>
EOF
echo "  [OK] Manager context.xml updated."

# ----------------------------------------------------------------
echo "====> Step 9: Allowing Host-Manager access from ANY IP..."
# ----------------------------------------------------------------
sudo mkdir -p "$INSTALL_DIR/webapps/host-manager/META-INF"
sudo tee "$INSTALL_DIR/webapps/host-manager/META-INF/context.xml" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!-- IP restriction removed: accessible from any IP -->
</Context>
EOF
echo "  [OK] Host-Manager context.xml updated."

# ----------------------------------------------------------------
echo "====> Step 10: Detecting JAVA_HOME for systemd service..."
# ----------------------------------------------------------------
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "  JAVA_HOME = $JAVA_HOME_PATH"

# ----------------------------------------------------------------
echo "====> Step 11: Creating systemd service file..."
# ----------------------------------------------------------------
sudo tee /etc/systemd/system/tomcat.service > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=${TOMCAT_USER}
Group=${TOMCAT_GROUP}

Environment="JAVA_HOME=${JAVA_HOME_PATH}"
Environment="CATALINA_PID=${INSTALL_DIR}/temp/tomcat.pid"
Environment="CATALINA_HOME=${INSTALL_DIR}"
Environment="CATALINA_BASE=${INSTALL_DIR}"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=${INSTALL_DIR}/bin/startup.sh
ExecStop=${INSTALL_DIR}/bin/shutdown.sh

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
echo "  [OK] systemd service created."

echo "====> Step 12: Enabling and starting Tomcat service..."
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

echo "====> Step 13: Opening port 8080 in UFW firewall..."
sudo ufw allow 8080/tcp 2>/dev/null && echo "  [OK] Port 8080 allowed." || echo "  [INFO] UFW not active or rule already exists."

# Wait a moment for Tomcat to fully start
sleep 5

echo ""
echo "============================================================"
echo "  Apache Tomcat ${TOMCAT_VERSION} installed successfully!"
echo ""
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "  Main URL     : http://${SERVER_IP}:8080"
echo "  Manager App  : http://${SERVER_IP}:8080/manager/html"
echo "  Host Manager : http://${SERVER_IP}:8080/host-manager/html"
echo "  Username     : ${TOMCAT_ADMIN_USER}"
echo "  Password     : ${TOMCAT_ADMIN_PASS}"
echo "============================================================"
echo ""
sudo systemctl status tomcat --no-pager
