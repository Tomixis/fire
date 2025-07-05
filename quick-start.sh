#!/bin/bash

echo "🚀 Quick VNC + Browser Setup for GitHub Codespaces"

# Install minimal dependencies
sudo apt-get update
sudo apt-get install -y xvfb x11vnc fluxbox firefox xterm

# Create quick setup directory
mkdir -p ~/quick-vnc
cd ~/quick-vnc

# Create simple startup script
cat > start.sh << 'EOF'
#!/bin/bash

echo "Starting VNC server..."

# Kill existing processes
pkill Xvfb || true
pkill x11vnc || true

# Start virtual display
Xvfb :99 -screen 0 1280x720x24 &
export DISPLAY=:99

# Wait for display
sleep 2

# Start window manager
fluxbox &
sleep 2

# Start VNC server
x11vnc -display :99 -nopw -listen localhost -xkb -forever -shared -rfbport 5900 &

# Wait for VNC
sleep 3

# Start Firefox
echo "Starting Firefox..."
firefox --no-remote --new-instance https://www.google.com &

# Start terminal
xterm -geometry 80x24+10+10 -title "Terminal" &

echo "✅ VNC server running on localhost:5900"
echo "🌐 Firefox started in kiosk mode"
echo "💻 Terminal available for debugging"

# Keep running
tail -f /dev/null
EOF

chmod +x start.sh

# Start the VNC server in background
echo "🔄 Starting VNC server..."
./start.sh &

# Wait a moment
sleep 5

echo ""
echo "✅ Quick setup complete!"
echo ""
echo "🌐 Access your VM's browser:"
echo "   - VNC Client: localhost:5900"
echo "   - No password required"
echo ""
echo "📱 To access from outside Codespaces:"
echo "   ngrok tcp 5900"
echo ""
echo "🔧 To check if it's running:"
echo "   ps aux | grep x11vnc"
echo "   netstat -tlnp | grep 5900"
echo ""
echo "🛑 To stop:"
echo "   pkill x11vnc"
echo "   pkill Xvfb" 