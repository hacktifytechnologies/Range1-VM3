#!/bin/bash

# ============================================================
#   Apache Tomcat Installation Script for Ubuntu 22.04 LTS
#   - Credentials: tomcat / tomcat
#   - Manager & Host-Manager open to all IPs
# ============================================================

set -e  # Exit immediately on any error

TOMCAT_VERSION="10.1.39"
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
INSTALL_DIR="/opt/tomcat"
JAVA_PACKAGE="openjdk-17-jdk"
TOMCAT_ADMIN_USER="tomcat"
TOMCAT_ADMIN_PASS="tomcat"

echo "====> Step 1: Updating system packages..."
sudo apt update -y && sudo apt upgrade -y

echo "====> Step 2: Installing Java (OpenJDK 17)..."
sudo apt install -y "$JAVA_PACKAGE"

echo "====> Verifying Java installation..."
java -version

echo "====> Step 3: Creating dedicated Tomcat user and group..."
sudo groupadd --system "$TOMCAT_GROUP" 2>/dev/null || echo "Group '$TOMCAT_GROUP' already exists."
sudo useradd -s /bin/false -g "$TOMCAT_GROUP" -d "$INSTALL_DIR" "$TOMCAT_USER" 2>/dev/null || echo "User '$TOMCAT_USER' already exists."

echo "====> Step 4: Downloading Apache Tomcat $TOMCAT_VERSION..."
TOMCAT_MAJOR=$(echo "$TOMCAT_VERSION" | cut -d. -f1)
TOMCAT_URL="https://downloads.apache.org/tomcat/tomcat-${TOMCAT_MAJOR}/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz"
wget -q "$TOMCAT_URL" -O /tmp/apache-tomcat.tar.gz

echo "====> Step 5: Extracting Tomcat to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo tar -xzf /tmp/apache-tomcat.tar.gz -C "$INSTALL_DIR" --strip-components=1
rm -f /tmp/apache-tomcat.tar.gz

echo "====> Step 6: Setting correct ownership and permissions..."
sudo chown -R "$TOMCAT_USER":"$TOMCAT_GROUP" "$INSTALL_DIR"
sudo chmod -R 750 "$INSTALL_DIR"
sudo chmod -R u+x "$INSTALL_DIR/bin"

# ============================================================
echo "====> Step 7: Configuring tomcat-users.xml (credentials)..."
# ============================================================
sudo tee "$INSTALL_DIR/conf/tomcat-users.xml" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">

  <!-- Roles -->
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>

  <!-- Admin User: tomcat / tomcat -->
  <user username="${TOMCAT_ADMIN_USER}"
        password="${TOMCAT_ADMIN_PASS}"
        roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>

</tomcat-users>
EOF

# ============================================================
echo "====> Step 8: Allowing Manager access from any IP..."
# ============================================================
# Remove the RemoteAddrValve restriction from /manager/META-INF/context.xml
sudo tee "$INSTALL_DIR/webapps/manager/META-INF/context.xml" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!-- RemoteAddrValve removed: access allowed from any IP -->
</Context>
EOF

# ============================================================
echo "====> Step 9: Allowing Host-Manager access from any IP..."
# ============================================================
# Remove the RemoteAddrValve restriction from /host-manager/META-INF/context.xml
sudo tee "$INSTALL_DIR/webapps/host-manager/META-INF/context.xml" > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!-- RemoteAddrValve removed: access allowed from any IP -->
</Context>
EOF

# ============================================================
echo "====> Step 10: Creating systemd service file..."
# ============================================================
JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))

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

echo "====> Step 11: Reloading systemd and enabling Tomcat service..."
sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

echo "====> Step 12: Configuring UFW firewall for port 8080..."
sudo ufw allow 8080/tcp 2>/dev/null || echo "UFW not active or rule already exists."

echo ""
echo "============================================================"
echo "  Apache Tomcat $TOMCAT_VERSION installed successfully!"
echo ""
echo "  URL         : http://$(hostname -I | awk '{print $1}'):8080"
echo "  Manager App : http://$(hostname -I | awk '{print $1}'):8080/manager/html"
echo "  Host Manager: http://$(hostname -I | awk '{print $1}'):8080/host-manager/html"
echo "  Username    : $TOMCAT_ADMIN_USER"
echo "  Password    : $TOMCAT_ADMIN_PASS"
echo "============================================================"
sudo systemctl status tomcat --no-pager
