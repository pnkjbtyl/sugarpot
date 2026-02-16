# Timeout Configuration Guide

## Problem
Large video files are being processed and thumbnailed, but the request times out before completion.

## Solution
Multiple timeout settings need to be increased:

### 1. Node.js/Express Server Timeouts
✅ **Already configured in `server.js`:**
- Server timeout: 30 minutes
- Keep-alive timeout: 30 minutes
- Request/Response timeout: 30 minutes
- Socket.io timeout: 30 minutes

### 2. Apache Reverse Proxy Timeouts

#### Option A: Virtual Host Configuration (Recommended)
Edit your Apache virtual host configuration file (usually in `/etc/apache2/sites-available/` or `/etc/httpd/conf.d/`):

```apache
<VirtualHost *:80>
    ServerName sugarpot.shree.systems
    
    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    # Increase timeout for large file uploads (30 minutes)
    Timeout 1800
    ProxyTimeout 1800
    
    # Increase request body size limit (200MB)
    LimitRequestBody 209715200
    
    # Enable required modules
    # Make sure these are enabled:
    # sudo a2enmod proxy
    # sudo a2enmod proxy_http
    # sudo a2enmod headers
</VirtualHost>

<VirtualHost *:443>
    ServerName sugarpot.shree.systems
    
    # SSL configuration here...
    
    ProxyPreserveHost On
    ProxyPass / http://localhost:3000/
    ProxyPassReverse / http://localhost:3000/
    
    # Increase timeout for large file uploads (30 minutes)
    Timeout 1800
    ProxyTimeout 1800
    
    # Increase request body size limit (200MB)
    LimitRequestBody 209715200
</VirtualHost>
```

#### Option B: .htaccess File
If you can't modify the virtual host, create a `.htaccess` file in your backend directory:

```apache
# Increase timeout
Timeout 1800

# Increase request body size (200MB)
LimitRequestBody 209715200
```

**Note:** `.htaccess` files only work if `AllowOverride` is enabled in your Apache configuration.

### 3. Apply Changes

After modifying Apache configuration:

```bash
# Test Apache configuration
sudo apache2ctl configtest
# or
sudo httpd -t

# If test passes, restart Apache
sudo systemctl restart apache2
# or
sudo systemctl restart httpd
```

### 4. Verify Configuration

Check if timeouts are applied:

```bash
# Check Apache timeout setting
apache2ctl -S | grep Timeout
# or
httpd -S | grep Timeout
```

### 5. Monitoring

The backend now logs:
- Upload request received (with file size and type)
- Processing start/end for images and videos
- Total processing time
- Errors with timestamps

Check logs:
```bash
# PM2 logs
pm2 logs sugarpot-backend

# Or if running directly
tail -f /path/to/backend/logs
```

## Troubleshooting

### Still timing out?
1. **Check Apache error logs:**
   ```bash
   sudo tail -f /var/log/apache2/error.log
   # or
   sudo tail -f /var/log/httpd/error_log
   ```

2. **Check if ProxyTimeout is set correctly:**
   ```bash
   apache2ctl -M | grep proxy
   ```

3. **Verify file size limits:**
   - Apache: `LimitRequestBody`
   - Node.js: Multer limits (200MB for videos)
   - Both should match or Node.js should be higher

4. **Check network timeouts:**
   - If using a load balancer, check its timeout settings
   - Check firewall/security group settings

### Alternative: Use Nginx
If Apache continues to cause issues, consider switching to Nginx which handles long-running requests better:

```nginx
proxy_read_timeout 1800s;
proxy_connect_timeout 1800s;
proxy_send_timeout 1800s;
client_max_body_size 200M;
```
