# Troubleshooting Guide

This guide helps you resolve common issues with the Linux passwd File Viewer.

## Quick Diagnostic Steps

1. **Check browser console**: Press F12 → Console tab
2. **Test file access**: Try accessing the passwd URL directly
3. **Verify web server**: Ensure web server is running
4. **Check permissions**: Verify file and directory permissions

## Common Issues & Solutions

### 🔴 CORS (Cross-Origin) Errors

**Symptoms:**
- "Access to fetch at '...' has been blocked by CORS policy"
- "No 'Access-Control-Allow-Origin' header is present"

**Solutions:**

#### For Apache:
```bash
# Method 1: Add to .htaccess
echo 'Header always set Access-Control-Allow-Origin "*"' | sudo tee /var/www/html/.htaccess

# Method 2: Add to Apache config
sudo tee /etc/apache2/conf-available/cors.conf << 'EOF'
<Files "passwd">
    Header always set Access-Control-Allow-Origin "*"
</Files>
EOF
sudo a2enmod headers
sudo a2enconf cors
sudo systemctl reload apache2
```

#### For Nginx:
```bash
# Add to server block
sudo tee -a /etc/nginx/sites-available/default << 'EOF'
location /passwd {
    add_header Access-Control-Allow-Origin *;
}
EOF
sudo systemctl reload nginx
```

#### For Python Server:
```python
# Create simple CORS-enabled server
cat > cors-server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
from urllib.parse import urlparse

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

PORT = 8080
with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
    print(f"Server running at http://localhost:{PORT}")
    httpd.serve_forever()
EOF
python3 cors-server.py
```

### 🔴 File Not Found (404 Errors)

**Symptoms:**
- "404 Not Found" when accessing passwd file
- Auto-update shows connection failed

**Diagnostic Steps:**
```bash
# Check if file exists
ls -la /var/www/html/passwd

# Check web server document root
# Apache:
grep DocumentRoot /etc/apache2/sites-available/000-default.conf
# Nginx:
grep root /etc/nginx/sites-available/default

# Test direct access
curl http://localhost/passwd
```

**Solutions:**
```bash
# Copy passwd file to correct location
sudo cp /etc/passwd /var/www/html/passwd

# Or create symbolic link
sudo ln -s /etc/passwd /var/www/html/passwd-live

# Fix permissions
sudo chmod 644 /var/www/html/passwd*
sudo chown www-data:www-data /var/www/html/passwd*
```

### 🔴 Permission Denied Errors

**Symptoms:**
- "403 Forbidden" errors
- "Permission denied" in server logs

**Solutions:**
```bash
# Fix file permissions
sudo chmod 644 /var/www/html/passwd
sudo chmod 755 /var/www/html

# Fix ownership
sudo chown www-data:www-data /var/www/html/passwd

# Check SELinux (if applicable)
sudo setsebool -P httpd_can_network_connect on
sudo restorecon -R /var/www/html/
```

### 🔴 Auto-Update Not Working

**Symptoms:**
- Status shows "offline" or "error"
- Manual refresh works but auto-update doesn't

**Diagnostic Steps:**
```bash
# Test URL accessibility
curl -I http://localhost/passwd

# Check browser console for JavaScript errors
# F12 → Console tab

# Verify network connectivity
ping localhost
telnet localhost 80
```

**Solutions:**
```bash
# Check auto-update interval settings
# Ensure interval is set correctly in browser

# Verify CORS is working
curl -H "Origin: http://localhost" -I http://localhost/passwd

# Restart web server
sudo systemctl restart apache2  # or nginx
```

### 🔴 Web Server Not Starting

**Symptoms:**
- "Connection refused" errors
- Server commands fail

**For Apache:**
```bash
# Check status
sudo systemctl status apache2

# Check for configuration errors
sudo apache2ctl -t

# Check error logs
sudo tail -f /var/log/apache2/error.log

# Start if stopped
sudo systemctl start apache2
```

**For Nginx:**
```bash
# Check status
sudo systemctl status nginx

# Check configuration
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/error.log

# Start if stopped
sudo systemctl start nginx
```

### 🔴 Port Already in Use

**Symptoms:**
- "Address already in use" errors
- Cannot start server on desired port

**Solutions:**
```bash
# Find what's using the port
sudo netstat -tulpn | grep :80
sudo lsof -i :80

# Kill process using port (if safe)
sudo kill $(sudo lsof -t -i:80)

# Use different port
python3 -m http.server 8080
```

### 🔴 File Upload Not Working

**Symptoms:**
- File selection doesn't work
- Upload button unresponsive

**Solutions:**
```bash
# Check browser compatibility
# Ensure modern browser (Chrome 60+, Firefox 55+)

# Clear browser cache
# Ctrl+F5 or Ctrl+Shift+R

# Check JavaScript errors in console
# F12 → Console tab

# Try different file
# Ensure file is valid passwd format
```

### 🔴 Styling/Display Issues

**Symptoms:**
- Broken layout
- Missing icons or fonts
- Theme not working

**Solutions:**
```bash
# Check internet connection for external fonts
ping fonts.googleapis.com
ping cdnjs.cloudflare.com

# Clear browser cache
# Hard refresh: Ctrl+F5

# Try different browser
# Test with Chrome, Firefox, Safari

# Check console for CSS errors
# F12 → Console tab
```

## Advanced Troubleshooting

### Network Debugging

```bash
# Test network connectivity
ping your-server.com
telnet your-server.com 80

# Check DNS resolution
nslookup your-server.com
dig your-server.com

# Test with curl
curl -v http://your-server.com/passwd
curl -H "Origin: http://localhost" -v http://your-server.com/passwd
```

### Server Log Analysis

#### Apache Logs:
```bash
# Error logs
sudo tail -f /var/log/apache2/error.log

# Access logs
sudo tail -f /var/log/apache2/access.log

# Filter for passwd-related requests
sudo grep passwd /var/log/apache2/access.log
```

#### Nginx Logs:
```bash
# Error logs
sudo tail -f /var/log/nginx/error.log

# Access logs
sudo tail -f /var/log/nginx/access.log

# Filter for passwd-related requests
sudo grep passwd /var/log/nginx/access.log
```

### Browser Debugging

#### Chrome/Chromium:
1. Open Developer Tools (F12)
2. Network tab → Record network activity
3. Console tab → Check for JavaScript errors
4. Application tab → Check Local Storage for settings

#### Firefox:
1. Open Developer Tools (F12)
2. Network tab → Monitor requests
3. Console tab → Check for errors
4. Storage tab → Local Storage for settings

### System Resource Issues

```bash
# Check disk space
df -h

# Check memory usage
free -h

# Check CPU usage
top
htop

# Check for resource limits
ulimit -a
```

### File System Issues

```bash
# Check file system errors
sudo dmesg | grep -i error

# Check file permissions recursively
find /var/www/html -name "passwd*" -exec ls -la {} \;

# Check for symbolic link issues
file /var/www/html/passwd*
readlink /var/www/html/passwd*
```

## Debugging Tools & Commands

### Network Testing:
```bash
# Test basic connectivity
curl -I http://localhost/passwd

# Test with headers
curl -H "Origin: http://example.com" -I http://localhost/passwd

# Test CORS preflight
curl -X OPTIONS -H "Origin: http://example.com" -I http://localhost/passwd

# Verbose output
curl -v http://localhost/passwd
```

### Server Testing:
```bash
# Apache configuration test
sudo apache2ctl -t
sudo apache2ctl -S  # Show virtual hosts

# Nginx configuration test
sudo nginx -t
sudo nginx -T  # Show full configuration

# Check loaded modules
# Apache:
apache2ctl -M
# Nginx:
nginx -V
```

### File Monitoring:
```bash
# Watch file changes
inotifywait -m /var/www/html/passwd -e modify,create,delete

# Monitor web access
sudo tail -f /var/log/apache2/access.log | grep passwd

# Watch system logs
sudo journalctl -f -u apache2
sudo journalctl -f -u nginx
```

## Performance Issues

### Slow Loading

**Symptoms:**
- Long loading times
- Timeouts

**Solutions:**
```bash
# Check server performance
top
iostat 1 5
netstat -i

# Optimize web server
# Apache:
echo "KeepAlive On" | sudo tee -a /etc/apache2/apache2.conf
# Nginx:
echo "keepalive_timeout 65;" | sudo tee -a /etc/nginx/nginx.conf

# Enable compression
# Apache:
sudo a2enmod deflate
# Nginx:
echo "gzip on;" | sudo tee -a /etc/nginx/nginx.conf
```

### Large File Handling

```bash
# Check file size
ls -lh /var/www/html/passwd

# For files > 1MB, consider filtering
awk -F: '$3 >= 1000' /etc/passwd > /var/www/html/passwd-users-only

# Split large files
split -l 1000 /etc/passwd /var/www/html/passwd-part-
```

## Getting Help

### Before Asking for Help:

1. **Check this troubleshooting guide**
2. **Look at server logs** (error and access logs)
3. **Test with curl commands** shown above
4. **Try the basic setup** (Python server) first
5. **Check browser console** for JavaScript errors

### Information to Include:

- **Operating System**: Ubuntu 20.04, CentOS 8, etc.
- **Web Server**: Apache 2.4, Nginx 1.18, Python 3.8, etc.
- **Browser**: Chrome 91, Firefox 89, Safari 14, etc.
- **Error Messages**: Exact error text from console/logs
- **Setup Method**: Which option from setup script you used
- **Network Setup**: Local, remote, Docker, etc.

### Log Collection:

```bash
# Collect system information
echo "=== System Info ===" > debug-info.txt
uname -a >> debug-info.txt
cat /etc/os-release >> debug-info.txt

echo "=== Web Server ===" >> debug-info.txt
apache2 -v >> debug-info.txt 2>&1 || nginx -v >> debug-info.txt 2>&1

echo "=== Network ===" >> debug-info.txt
netstat -tulpn | grep -E ':80|:443|:8080' >> debug-info.txt

echo "=== File Permissions ===" >> debug-info.txt
ls -la /var/www/html/passwd* >> debug-info.txt

echo "=== Recent Errors ===" >> debug-info.txt
sudo tail -20 /var/log/apache2/error.log >> debug-info.txt 2>&1
sudo tail -20 /var/log/nginx/error.log >> debug-info.txt 2>&1
```

## Prevention Tips

1. **Test after setup**: Always test functionality after configuration changes
2. **Monitor logs**: Regularly check server logs for errors
3. **Keep backups**: Backup working configurations
4. **Document changes**: Keep notes of what you modified
5. **Use version control**: Track configuration file changes
6. **Regular updates**: Keep system and server software updated
7. **Security first**: Don't disable security features for convenience