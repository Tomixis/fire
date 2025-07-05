# 🖥️ VNC Browser Access for GitHub Codespaces

This project provides a solution to access a browser running inside your GitHub Codespace VM, solving the proxy limitations you encountered.

## 🎯 Why This Approach?

Instead of trying to proxy websites (which gets blocked by YouTube, banking sites, etc.), this solution:

- ✅ **Runs browser natively** in the VM
- ✅ **No anti-proxy detection** - websites see a real browser
- ✅ **Perfect compatibility** - works with all sites including YouTube
- ✅ **True isolation** - VM can have different IP/location
- ✅ **No URL rewriting** - everything works as expected

## 🚀 Quick Start (Recommended)

For immediate testing in your Codespace:

```bash
# Make script executable
chmod +x quick-start.sh

# Run the quick setup
./quick-start.sh
```

This will:
1. Install minimal dependencies
2. Start a VNC server on port 5900
3. Launch Firefox in the VM
4. Provide access to the VM's browser

## 🌐 Access Methods

### 1. VNC Client (Recommended)
- Use any VNC client (VNC Viewer, RealVNC, etc.)
- Connect to: `localhost:5900`
- No password required

### 2. Web-based Access (Advanced Setup)
For web-based access, use the full setup:

```bash
chmod +x simple-vnc-setup.sh
./simple-vnc-setup.sh
```

This provides:
- Web interface at `http://localhost`
- Web VNC client at `http://localhost:6080`

### 3. External Access
To access from outside your Codespace:

```bash
# Expose VNC port
ngrok tcp 5900

# Or expose web interface
ngrok http 80
```

## 📁 File Structure

- `quick-start.sh` - Minimal setup for immediate testing
- `simple-vnc-setup.sh` - Full setup with web interface
- `guacamole-setup.sh` - Enterprise-grade setup with Guacamole
- `proxyv*.js` - Previous proxy attempts (kept for reference)

## 🔧 Troubleshooting

### Check if VNC is running:
```bash
ps aux | grep x11vnc
netstat -tlnp | grep 5900
```

### Restart VNC server:
```bash
pkill x11vnc
pkill Xvfb
cd ~/quick-vnc
./start.sh &
```

### View logs:
```bash
# Check supervisor logs (if using full setup)
sudo tail -f /var/log/vnc-server.out.log
```

## 🎯 Use Cases

This solution is perfect for:

- **YouTube/Netflix** - No proxy detection
- **Banking sites** - Full security features work
- **Web scraping** - Real browser environment
- **Testing** - Isolated browser sessions
- **Privacy** - VM can use different IP/location

## 🔒 Security Notes

- VNC server runs without password (for testing)
- Only accessible from localhost by default
- Use SSH tunnels for remote access
- Consider adding VNC password for production use

## 🚀 Next Steps

1. **Test the quick setup** with `./quick-start.sh`
2. **Access via VNC client** at `localhost:5900`
3. **Try accessing YouTube** - it should work perfectly!
4. **Expose externally** with ngrok if needed

This approach completely eliminates the proxy limitations you were experiencing!