const express = require('express');
//const fetch = require('node-fetch');
const cors = require('cors');
const app = express();

app.use(cors());

app.get('/website', async (req, res) => {
    const targetUrl = req.query.url;
    
    if (!targetUrl) {
        return res.status(400).json({ error: 'URL parameter is required' });
    }
    
    try {
        const url = targetUrl.startsWith('http') ? targetUrl : `https://${targetUrl}`;
        const baseUrl = new URL(url).origin;
        
        const response = await fetch(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
                'Accept-Encoding': 'gzip, deflate',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1'
            },
            redirect: 'manual'
        });
        
        // Handle redirects by following them
        if (response.status >= 300 && response.status < 400) {
            const location = response.headers.get('location');
            if (location) {
                const redirectUrl = location.startsWith('http') ? location : new URL(location, baseUrl).href;
                return res.redirect(`/website?url=${encodeURIComponent(redirectUrl)}`);
            }
        }
        
        const html = await response.text();
        
        // More comprehensive URL rewriting
        let modifiedHtml = html
            // Fix relative URLs in href and src
            .replace(/(href|src)="\/([^"]*?)"/g, `$1="${baseUrl}/$2"`)
            .replace(/(href|src)="(?!http|\/\/|mailto:|tel:|javascript:|#)([^"]*?)"/g, `$1="${baseUrl}/$2`)
            // Fix CSS url() references
            .replace(/url\(["']?\/([^"')]*?)["']?\)/g, `url("${baseUrl}/$1")`)
            // Fix JavaScript redirects and location changes
            .replace(/window\.location\s*=\s*["']([^"']*?)["']/g, `window.location = "/website?url=${encodeURIComponent('$1')}"`)
            .replace(/location\.href\s*=\s*["']([^"']*?)["']/g, `location.href = "/website?url=${encodeURIComponent('$1')}"`)
            // Fix forms to submit through proxy
            .replace(/<form([^>]*?)action="([^"]*?)"([^>]*?)>/g, (match, before, action, after) => {
                const fullAction = action.startsWith('http') ? action : new URL(action, baseUrl).href;
                return `<form${before}action="/website?url=${encodeURIComponent(fullAction)}"${after}>`;
            })
            // Add base tag to help with relative URLs
            .replace(/<head>/i, `<head><base href="${baseUrl}/">`)
            // Prevent page from redirecting away from proxy
            .replace(/<meta[^>]*http-equiv="refresh"[^>]*>/gi, '')
            // Fix AJAX requests
            .replace(/fetch\s*\(\s*["']([^"']*?)["']/g, (match, fetchUrl) => {
                const fullFetchUrl = fetchUrl.startsWith('http') ? fetchUrl : new URL(fetchUrl, baseUrl).href;
                return `fetch("/website?url=${encodeURIComponent(fullFetchUrl)}"`;
            });
        
        res.setHeader('Content-Type', 'text/html');
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('X-Frame-Options', 'ALLOWALL');
        res.send(modifiedHtml);
        
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch website: ' + error.message });
    }
});

// Handle POST requests for forms
app.post('/website', express.urlencoded({ extended: true }), async (req, res) => {
    const targetUrl = req.query.url;
    
    if (!targetUrl) {
        return res.status(400).json({ error: 'URL parameter is required' });
    }
    
    try {
        const response = await fetch(targetUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            },
            body: new URLSearchParams(req.body).toString()
        });
        
        const html = await response.text();
        // Apply same modifications as GET request
        res.setHeader('Content-Type', 'text/html');
        res.send(html);
        
    } catch (error) {
        res.status(500).json({ error: 'Failed to submit form: ' + error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`Enhanced proxy server running on port ${PORT}`);
    console.log(`Usage: http://your-server:${PORT}/website?url=youtube.com`);
});