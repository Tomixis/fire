#!/bin/bash

echo "🚀 Setting up Guacamole in GitHub Codespace..."

# Update system
sudo apt-get update

# Install required dependencies
echo "📦 Installing dependencies..."
sudo apt-get install -y \
    wget \
    curl \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    xvfb \
    x11vnc \
    fluxbox \
    firefox \
    chromium-browser \
    openbox \
    xterm \
    supervisor \
    nginx \
    default-jdk \
    maven \
    tomcat9 \
    tomcat9-admin

# Install Docker (for easier Guacamole setup)
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Create directories
echo "📁 Creating directories..."
mkdir -p ~/guacamole
mkdir -p ~/guacamole/init
mkdir -p ~/guacamole/drive
mkdir -p ~/guacamole/record

# Download and setup Guacamole with Docker Compose
echo "🔧 Setting up Guacamole with Docker..."
cd ~/guacamole

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  guacamole:
    image: guacamole/guacamole:latest
    container_name: guacamole
    environment:
      GUACD_HOSTNAME: guacd
    ports:
      - "8080:8080"
    depends_on:
      - guacd
      - postgres
    restart: unless-stopped

  guacd:
    image: guacamole/guacd:latest
    container_name: guacd
    restart: unless-stopped

  postgres:
    image: postgres:13
    container_name: postgres
    environment:
      POSTGRES_DB: guacamole_db
      POSTGRES_USER: guacamole_user
      POSTGRES_PASSWORD: guacamole_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init:/docker-entrypoint-initdb.d
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# Create database initialization script
cat > init/initdb.sql << 'EOF'
-- Create guacamole database
CREATE DATABASE guacamole_db;
GRANT ALL PRIVILEGES ON DATABASE guacamole_db TO guacamole_user;

-- Connect to guacamole database
\c guacamole_db;

-- Create guacamole tables
CREATE TABLE guacamole_connection (
    connection_id   serial       NOT NULL,
    connection_name varchar(128) NOT NULL,
    protocol        varchar(32)  NOT NULL,
    PRIMARY KEY (connection_id),
    UNIQUE (connection_name)
);

CREATE TABLE guacamole_connection_parameter (
    connection_id   integer       NOT NULL,
    parameter_name  varchar(128)  NOT NULL,
    parameter_value text          NOT NULL,
    PRIMARY KEY (connection_id,parameter_name),
    FOREIGN KEY (connection_id) REFERENCES guacamole_connection(connection_id) ON DELETE CASCADE
);

CREATE TABLE guacamole_user (
    user_id       serial       NOT NULL,
    username      varchar(128) NOT NULL,
    password_hash varchar(32)  NOT NULL,
    PRIMARY KEY (user_id),
    UNIQUE (username)
);

CREATE TABLE guacamole_user_permission (
    user_id       integer NOT NULL,
    username      varchar(128) NOT NULL,
    permission    varchar(16) NOT NULL,
    PRIMARY KEY (user_id,permission),
    FOREIGN KEY (user_id) REFERENCES guacamole_user(user_id) ON DELETE CASCADE
);

-- Insert default admin user (username: guacadmin, password: guacadmin)
INSERT INTO guacamole_user (username, password_hash) VALUES ('guacadmin', '5f4dcc3b5aa765d61d8327deb882cf99');
INSERT INTO guacamole_user_permission (user_id, username, permission) VALUES (1, 'guacadmin', 'ADMINISTER');
EOF

# Create VNC startup script
cat > start-vnc.sh << 'EOF'
#!/bin/bash

# Start virtual display
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99

# Start window manager
fluxbox &
sleep 2

# Start VNC server
x11vnc -display :99 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever -shared &

# Start browser (Firefox)
firefox --no-remote --new-instance &
# Or use Chromium:
# chromium-browser --no-sandbox --disable-dev-shm-usage &

# Keep script running
tail -f /dev/null
EOF

chmod +x start-vnc.sh

# Create systemd service for VNC
sudo tee /etc/systemd/system/vnc-server.service > /dev/null << 'EOF'
[Unit]
Description=VNC Server
After=network.target

[Service]
Type=simple
User=codespace
Environment=DISPLAY=:99
ExecStart=/home/codespace/guacamole/start-vnc.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create nginx configuration
sudo tee /etc/nginx/sites-available/guacamole > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;
        proxy_cookie_path /guacamole/ /;
        access_log off;
    }
}
EOF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/guacamole /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Start services
echo "🔄 Starting services..."
sudo systemctl enable vnc-server
sudo systemctl start vnc-server
sudo systemctl restart nginx

# Start Guacamole with Docker
echo "🐳 Starting Guacamole containers..."
cd ~/guacamole
docker-compose up -d

echo "✅ Setup complete!"
echo ""
echo "🌐 Access URLs:"
echo "   - Guacamole: http://localhost:8080/guacamole"
echo "   - VNC Direct: localhost:5900"
echo ""
echo "🔑 Default credentials:"
echo "   Username: guacadmin"
echo "   Password: guacadmin"
echo ""
echo "📝 Next steps:"
echo "   1. Access Guacamole at http://localhost:8080/guacamole"
echo "   2. Login with guacadmin/guacadmin"
echo "   3. Add a new VNC connection:"
echo "      - Protocol: VNC"
echo "      - Hostname: localhost"
echo "      - Port: 5900"
echo "   4. Connect and use the browser in the VM!"
echo ""
echo "🌍 To expose externally, use ngrok:"
echo "   ngrok http 8080" 