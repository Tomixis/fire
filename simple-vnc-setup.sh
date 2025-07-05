#!/bin/bash

echo "🚀 Setting up Simple VNC + Browser in GitHub Codespace..."

# Update system
sudo apt-get update

# Install required packages
echo "📦 Installing dependencies..."
sudo apt-get install -y \
    xvfb \
    x11vnc \
    fluxbox \
    firefox \
    chromium-browser \
    xterm \
    nginx \
    supervisor

# Create directories
mkdir -p ~/vnc-setup
cd ~/vnc-setup

# Create VNC startup script
cat > start-vnc.sh << 'EOF'
#!/bin/bash

echo "Starting VNC server..."

# Kill any existing Xvfb processes
pkill Xvfb || true
pkill x11vnc || true

# Start virtual display
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
export DISPLAY=:99

# Wait for display to be ready
sleep 2

# Start window manager
fluxbox &
sleep 2

# Start VNC server
x11vnc -display :99 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever -shared -rfbport 5900 &

# Wait for VNC to start
sleep 3

# Start browser (Firefox)
echo "Starting Firefox..."
firefox --no-remote --new-instance --kiosk https://www.google.com &

# Also start a terminal for debugging
xterm -geometry 80x24+10+10 -title "Debug Terminal" &

echo "VNC server started on localhost:5900"
echo "Display: :99"

# Keep script running
while true; do
    sleep 10
    # Check if processes are still running
    if ! pgrep -x "Xvfb" > /dev/null; then
        echo "Xvfb died, restarting..."
        Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
        sleep 2
    fi
    if ! pgrep -x "x11vnc" > /dev/null; then
        echo "x11vnc died, restarting..."
        x11vnc -display :99 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever -shared -rfbport 5900 &
    fi
done
EOF

chmod +x start-vnc.sh

# Create supervisor configuration
sudo tee /etc/supervisor/conf.d/vnc.conf > /dev/null << 'EOF'
[program:vnc-server]
command=/home/codespace/vnc-setup/start-vnc.sh
user=codespace
autostart=true
autorestart=true
stderr_logfile=/var/log/vnc-server.err.log
stdout_logfile=/var/log/vnc-server.out.log
environment=DISPLAY=":99"
EOF

# Create simple web interface
cat > web-interface.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>VNC Browser Access</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .container { background: #f5f5f5; padding: 30px; border-radius: 10px; }
        .button { display: inline-block; padding: 15px 30px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; margin: 10px; }
        .button:hover { background: #0056b3; }
        .info { background: white; padding: 15px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #007bff; }
        .url { font-family: monospace; color: #007bff; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ VNC Browser Access</h1>
        <p>Access the VM's browser through VNC connection.</p>
        
        <div class="info">
            <h3>Connection Details:</h3>
            <p><strong>Host:</strong> <span class="url">localhost</span></p>
            <p><strong>Port:</strong> <span class="url">5900</span></p>
            <p><strong>Password:</strong> None (unsecured for testing)</p>
        </div>
        
        <h3>Access Methods:</h3>
        
        <div class="info">
            <h4>1. Web-based VNC Client</h4>
            <a href="http://localhost:6080" class="button" target="_blank">Open Web VNC Client</a>
            <p>Uses noVNC for browser-based access</p>
        </div>
        
        <div class="info">
            <h4>2. Desktop VNC Client</h4>
            <p>Use any VNC client (VNC Viewer, RealVNC, etc.)</p>
            <p>Connect to: <span class="url">localhost:5900</span></p>
        </div>
        
        <div class="info">
            <h4>3. SSH Tunnel (if accessing remotely)</h4>
            <p>Create SSH tunnel: <span class="url">ssh -L 5900:localhost:5900 user@your-server</span></p>
        </div>
        
        <h3>What's Running:</h3>
        <ul>
            <li>✅ Virtual Display (Xvfb)</li>
            <li>✅ VNC Server (x11vnc)</li>
            <li>✅ Window Manager (Fluxbox)</li>
            <li>✅ Firefox Browser</li>
            <li>✅ Debug Terminal</li>
        </ul>
        
        <h3>External Access:</h3>
        <p>To expose externally, use ngrok:</p>
        <span class="url">ngrok tcp 5900</span>
    </div>
</body>
</html>
EOF

# Install noVNC for web-based access
echo "🌐 Installing noVNC for web access..."
cd ~/vnc-setup
git clone https://github.com/novnc/noVNC.git
cd noVNC
git checkout v1.4.0
cp vnc.html index.html

# Create noVNC startup script
cat > start-novnc.sh << 'EOF'
#!/bin/bash
cd ~/vnc-setup/noVNC
./utils/novnc_proxy --vnc localhost:5900 --listen 6080
EOF

chmod +x start-novnc.sh

# Add noVNC to supervisor
sudo tee -a /etc/supervisor/conf.d/vnc.conf > /dev/null << 'EOF'

[program:novnc]
command=/home/codespace/vnc-setup/start-novnc.sh
user=codespace
autostart=true
autorestart=true
stderr_logfile=/var/log/novnc.err.log
stdout_logfile=/var/log/novnc.out.log
EOF

# Create nginx configuration for web interface
sudo tee /etc/nginx/sites-available/vnc-interface > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        root /home/codespace/vnc-setup;
        index web-interface.html;
    }
}
EOF

# Enable nginx site
sudo ln -sf /etc/nginx/sites-available/vnc-interface /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Start services
echo "🔄 Starting services..."
sudo systemctl restart supervisor
sudo systemctl restart nginx

# Wait for services to start
sleep 5

echo "✅ Setup complete!"
echo ""
echo "🌐 Access URLs:"
echo "   - Web Interface: http://localhost"
echo "   - Web VNC Client: http://localhost:6080"
echo "   - VNC Direct: localhost:5900"
echo ""
echo "📝 Usage:"
echo "   1. Open http://localhost to see the interface"
echo "   2. Click 'Open Web VNC Client' to access the browser"
echo "   3. Or use any VNC client to connect to localhost:5900"
echo ""
echo "🌍 To expose externally:"
echo "   ngrok tcp 5900  # For VNC"
echo "   ngrok http 80   # For web interface"
echo "   ngrok http 6080 # For web VNC client"
EOF 