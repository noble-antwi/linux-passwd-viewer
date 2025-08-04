# Deployment Guide

This guide covers various deployment scenarios for the Linux passwd File Viewer.

## Quick Deployment Options

### 1. Localhost Testing (No Server Setup)

Perfect for testing or personal use:

```bash
# Download the main file
wget https://raw.githubusercontent.com/yourusername/linux-passwd-viewer/main/index.html

# Open directly in browser
firefox index.html
```

**Pros**: No setup required, works offline
**Cons**: No auto-update functionality

### 2. Simple Python Server

Great for development and testing:

```bash
# Create directory and copy files
mkdir ~/passwd-viewer
cp /etc/passwd ~/passwd-viewer/
cd ~/passwd-viewer

# Download the application
wget https://raw.githubusercontent.com/yourusername/linux-passwd-viewer/main/index.html

# Start server
python3 -m http.server 8080

# Access at: http://localhost:8080
```

**Pros**: Quick setup, auto-update works
**Cons**: Basic server, development only

### 3. Apache Integration

For production environments with Apache:

```bash
# Copy files to web directory
sudo cp index.html /var/www/html/passwd-viewer.html
sudo cp /etc/passwd /var/www/html/passwd

# Configure CORS (choose one method):

# Method A: Create .htaccess file
sudo tee /var/www/html/.htaccess << 'EOF'
<Files "passwd">
    Header always set Access-Control-Allow-Origin "*"
</Files>
EOF

# Method B: Add to Apache site config
sudo tee /etc/apache2/conf-available/passwd-viewer.conf << 'EOF'
<Files "passwd">
    Header always set Access-Control-Allow-Origin "*"
</Files>
EOF
sudo a2enmod headers
sudo a2enconf passwd-viewer
sudo systemctl reload apache2

# Access at: http://server/passwd-viewer.html
```

### 4. Nginx Integration

For production environments with Nginx:

```bash
# Copy files
sudo cp index.html /var/www/html/passwd-viewer.html
sudo cp /etc/passwd /var/www/html/passwd

# Add to Nginx config
sudo tee -a /etc/nginx/sites-available/default << 'EOF'
location ~ ^/(passwd|passwd-live)$ {
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "no-cache, must-revalidate";
}
EOF

sudo systemctl reload nginx

# Access at: http://server/passwd-viewer.html
```

### 5. Symbolic Link Method (Recommended)

Safest real-time monitoring approach:

```bash
# Create symbolic links
sudo ln -s /etc/passwd /var/www/html/passwd-live
sudo cp index.html /var/www/html/passwd-viewer.html

# Configure CORS for linked files
sudo tee /etc/apache2/conf-available/symlink-cors.conf << 'EOF'
<Files "*-live">
    Header always set Access-Control-Allow-Origin "*"
</Files>
EOF
sudo a2enmod headers
sudo a2enconf symlink-cors
sudo systemctl reload apache2

# Access: http://server/passwd-viewer.html
# Monitor URL: http://server/passwd-live
```

**Pros**: Real-time updates, secure, no copying
**Cons**: Requires web server setup

### 6. File Watcher with Auto-Copy

Automatic updates when passwd file changes:

```bash
# Install inotify-tools
sudo apt install inotify-tools

# Create watcher script
sudo tee /usr/local/bin/passwd-watcher.sh << 'EOF'
#!/bin/bash
inotifywait -m /etc/passwd -e modify --format '%w%f' | while read file; do
    cp "$file" /var/www/html/passwd
    echo "$(date): passwd file updated"
done
EOF

sudo chmod +x /usr/local/bin/passwd-watcher.sh

# Run as background service
sudo /usr/local/bin/passwd-watcher.sh &

# Or create systemd service (see examples/systemd-service.conf)
```

### 7. Docker Deployment

Containerized deployment:

```bash
# Create Dockerfile
cat > Dockerfile << 'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
COPY examples/nginx-config.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
EOF

# Build and run
docker build -t passwd-viewer .
docker run -d -p 8080:80 -v /etc/passwd:/usr/share/nginx/html/passwd:ro passwd-viewer

# Access at: http://localhost:8080
```

## Advanced Deployment Scenarios

### Remote Server Access (SSH)

For managing remote Linux servers:

```bash
# From local machine, copy files to server
scp index.html setup-auto-update.sh user@server:~/

# SSH into server
ssh user@server

# Run setup script
chmod +x setup-auto-update.sh
./setup-auto-update.sh

# Choose appropriate option for your needs
```

### Multiple Server Monitoring

Monitor multiple servers from one interface:

```bash
# On each server, set up with unique port
./setup-auto-update.sh  # Choose Python server with different ports

# Server 1: http://server1:8080/passwd
# Server 2: http://server2:8081/passwd
# Server 3: http://server3:8082/passwd
```

### High-Security Environment

For environments requiring strict security:

```bash
# Bind only to localhost
python3 -m http.server 8080 --bind 127.0.0.1

# Use SSH tunneling from client
ssh -L 8080:localhost:8080 user@server

# Access via: http://localhost:8080
```

### Load Balancer Setup

For high-availability deployments:

```bash
# Set up on multiple web servers
# Configure load balancer (Nginx example)
upstream passwd_viewers {
    server web1:80;
    server web2:80;
    server web3:80;
}

server {
    listen 80;
    location / {
        proxy_pass http://passwd_viewers;
    }
}
```

## Environment-Specific Considerations

### Development Environment
- Use Python HTTP server
- Enable CORS for all origins
- Use file upload method for testing

### Staging Environment
- Use symbolic links
- Configure basic authentication
- Monitor with moderate intervals (30 seconds)

### Production Environment
- Use copy-based method with file watcher
- Implement proper authentication
- Use HTTPS
- Monitor access logs
- Set up appropriate firewall rules

## Security Deployment Checklist

- [ ] **Authentication**: Implement basic auth or IP restrictions
- [ ] **HTTPS**: Use SSL/TLS in production
- [ ] **Firewall**: Configure appropriate access rules
- [ ] **File Permissions**: Set correct permissions (644 for passwd)
- [ ] **Access Logs**: Monitor who accesses the files
- [ ] **Regular Updates**: Keep web server and system updated
- [ ] **Backup**: Regular backup of configuration files

## Troubleshooting Deployment Issues

### CORS Errors
```bash
# Check if CORS headers are set
curl -I http://server/passwd

# Should see: Access-Control-Allow-Origin: *
```

### File Permission Issues
```bash
# Fix file permissions
sudo chmod 644 /var/www/html/passwd
sudo chown www-data:www-data /var/www/html/passwd
```

### Service Not Starting
```bash
# Check service status
sudo systemctl status apache2
sudo systemctl status nginx

# Check error logs
sudo journalctl -u apache2 -f
sudo journalctl -u nginx -f
```

### Network Connectivity
```bash
# Test from client machine
curl http://server:8080/passwd

# Check firewall
sudo ufw status
sudo iptables -L
```

## Performance Optimization

### For Large passwd Files
- Enable gzip compression on server
- Set appropriate cache headers
- Use CDN for static files

### For High Traffic
- Set up multiple server instances
- Use load balancing
- Implement caching strategies

### For Slow Networks
- Minimize auto-update frequency
- Implement compression
- Use efficient polling strategies