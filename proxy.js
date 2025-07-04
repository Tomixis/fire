const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const app = express();

// Enable CORS for all routes
app.use(cors());

// Proxy route handler
app.get('/website', async (req, res) => {
    const targetUrl = req.query.url;
    
    if (!targetUrl) {
        return res.status(400).json({ error: 'URL parameter is required' });
    }
    
    try {
        // Validate URL format
        const url = new URL(targetUrl.startsWith('http') ? targetUrl : `https://${targetUrl}`);
        
        // Create proxy middleware
        const proxy = createProxyMiddleware({
            target: url.origin,
            changeOrigin: true,
            pathRewrite: {
                '^/website': url.pathname + url.search
            },
            onProxyReq: (proxyReq, req, res) => {
                // Remove problematic headers
                proxyReq.removeHeader('referer');
                proxyReq.removeHeader('origin');
            },
            onProxyRes: (proxyRes, req, res) => {
                // Modify response headers to prevent CORS issues
                proxyRes.headers['access-control-allow-origin'] = '*';
                proxyRes.headers['access-control-allow-methods'] = 'GET, POST, PUT, DELETE, OPTIONS';
                proxyRes.headers['access-control-allow-headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization';
                
                // Remove security headers that might interfere
                delete proxyRes.headers['x-frame-options'];
                delete proxyRes.headers['content-security-policy'];
            }
        });
        
        proxy(req, res);
        
    } catch (error) {
        res.status(400).json({ error: 'Invalid URL provided' });
    }
});

// Alternative route for direct HTML fetching (simpler approach)
app.get('/fetch', async (req, res) => {
    const targetUrl = req.query.url;
    
    if (!targetUrl) {
        return res.status(400).json({ error: 'URL parameter is required' });
    }
    
    try {
        const fetch = require('node-fetch');
        const url = targetUrl.startsWith('http') ? targetUrl : `https://${targetUrl}`;
        
        const response = await fetch(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
        });
        
        const html = await response.text();
        
        // Modify HTML to fix relative URLs
        const modifiedHtml = html.replace(
            /(src|href)="(?!http|\/\/|mailto:|tel:)([^"]*?)"/g,
            `$1="${new URL(url).origin}/$2"`
        );
        
        res.setHeader('Content-Type', 'text/html');
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.send(modifiedHtml);
        
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch website: ' + error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Proxy server running on port ${PORT}`);
    console.log(`Usage: http://psychic-computing-machine-6q4x59r95rvfxv7r.github.dev/:${PORT}/website?url=example.com`);
    console.log(`Or: http://psychic-computing-machine-6q4x59r95rvfxv7r.github.dev/${PORT}/fetch?url=example.com`);
});