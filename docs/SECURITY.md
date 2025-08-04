# Security Guide

Security is paramount when exposing system files like `/etc/passwd` via web interfaces. This guide outlines security considerations and best practices.

## Security Risk Assessment

### Risk Levels by Method

| Method | Risk Level | Security Concerns | Recommended For |
|--------|------------|-------------------|-----------------|
| File Upload | 🟢 **LOW** | Local file only | Development, testing |
| Copy Method | 🟡 **MEDIUM** | Exposed copy of file | Production with controls |
| Symbolic Link | 🟡 **MEDIUM** | Direct file access | Controlled production |
| Direct /etc Access | 🔴 **HIGH** | Entire /etc directory exposed | Development only |

## Security Best Practices

### 1. Authentication & Authorization

#### Basic Authentication (Apache)
```apache
<Directory "/var/www/html">
    AuthType Basic
    AuthName "passwd Viewer Access"
    AuthUserFile /etc/apache2/.htpasswd
    Require valid-user
</Directory>
```

#### Basic Authentication (Nginx)
```nginx
location / {
    auth_basic "passwd Viewer Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

#### Create Password File
```bash
# Create htpasswd file
sudo htpasswd -c /etc/apache2/.htpasswd admin
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Set appropriate permissions
sudo chmod 644 /etc/apache2/.htpasswd
sudo chmod 644 /etc/nginx/.htpasswd
```

### 2. Network Security

#### Firewall Configuration
```bash
# Allow specific IP ranges only
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw allow from 10.0.0.0/8 to any port 80

# Block all other access
sudo ufw deny 80

# Or allow only localhost
sudo ufw allow from 127.0.0.1 to any port 8080
```

#### SSH Tunneling (Recommended for Remote Access)
```bash
# From client machine
ssh -L 8080:localhost:8080 user@server

# Then access via: http://localhost:8080
```

#### VPN Access
```bash
# Restrict to VPN networks only
sudo ufw allow from 10.8.0.0/24 to any port 80  # OpenVPN
sudo ufw allow from 10.3.0.0/24 to any port 80  # WireGuard
```

### 3. File Security

#### File Permissions
```bash
# Secure passwd file permissions
sudo chmod 644 /etc/passwd  # Standard passwd permissions
sudo chmod 644 /var/www/html/passwd  # Web-accessible copy

# Secure web directory
sudo chown root:www-data /var/www/html/passwd
sudo chmod 644 /var/www/html/passwd
```

#### Content Filtering
```bash
# Create filtered passwd file (remove sensitive entries)
grep -v "^root\|^mysql\|^postgres" /etc/passwd > /var/www/html/passwd-filtered

# Or create custom filter script
cat > /usr/local/bin/filter-passwd.sh << 'EOF'
#!/bin/bash
# Remove system accounts and sensitive users
awk -F: '$3 >= 1000 || $1 == "root"' /etc/passwd | \
  grep -v "^backup\|^nobody\|^_" > /var/www/html/passwd-filtered
EOF
chmod +x /usr/local/bin/filter-passwd.sh
```

### 4. Web Server Security

#### Security Headers (Apache)
```apache
# Add security headers
Header always set X-Content-Type-Options nosniff
Header always set X-Frame-Options DENY
Header always set X-XSS-Protection "1; mode=block"
Header always set Content-Security-Policy "default-src 'self'"
Header always set Referrer-Policy "strict-origin-when-cross-origin"
```

#### Security Headers (Nginx)
```nginx
# Add security headers
add_header X-Content-Type-Options nosniff;
add_header X-Frame-Options DENY;
add_header X-XSS-Protection "1; mode=block";
add_header Content-Security-Policy "default-src 'self'";
add_header Referrer-Policy "strict-origin-when-cross-origin";
```

#### Disable Directory Listing
```apache
# Apache
Options -Indexes
```

```nginx
# Nginx
autoindex off;
```

### 5. HTTPS/TLS Configuration

#### Let's Encrypt (Free SSL)
```bash
# Install certbot
sudo apt install certbot python3-certbot-apache  # For Apache
sudo apt install certbot python3-certbot-nginx   # For Nginx

# Get certificate
sudo certbot --apache -d your-domain.com
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

#### Force HTTPS
```apache
# Apache - redirect HTTP to HTTPS
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

```nginx
# Nginx - redirect HTTP to HTTPS
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}
```

### 6. Logging & Monitoring

#### Access Logging
```apache
# Apache - Enhanced logging
LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
CustomLog /var/log/apache2/passwd-viewer-access.log combined
```

```nginx
# Nginx - Enhanced logging
log_format detailed '$remote_addr - $remote_user [$time_local] '
                   '"$request" $status $body_bytes_sent '
                   '"$http_referer" "$http_user_agent"'
access_log /var/log/nginx/passwd-viewer-access.log detailed;
```

#### Monitor Access Patterns
```bash
# Create monitoring script
cat > /usr/local/bin/monitor-passwd-access.sh << 'EOF'
#!/bin/bash
# Monitor for suspicious access patterns

LOG_FILE="/var/log/nginx/passwd-viewer-access.log"  # Or Apache log
ALERT_EMAIL="admin@yourdomain.com"

# Check for excessive requests from single IP
tail -n 1000 "$LOG_FILE" | awk '{print $1}' | sort | uniq -c | sort -nr | head -5 | \
while read count ip; do
    if [ "$count" -gt 100 ]; then
        echo "Warning: IP $ip made $count requests" | \
        mail -s "passwd Viewer: Excessive Access Alert" "$ALERT_EMAIL"
    fi
done
EOF

chmod +x /usr/local/bin/monitor-passwd-access.sh

# Run every 10 minutes
echo "*/10 * * * * /usr/local/bin/monitor-passwd-access.sh" | sudo crontab -
```

### 7. Application-Level Security

#### Input Validation
The application already includes:
- XSS protection through proper HTML escaping
- No user input processing server-side
- Client-side file validation

#### Rate Limiting
```nginx
# Nginx rate limiting
http {
    limit_req_zone $binary_remote_addr zone=passwd:10m rate=1r/s;
    
    server {
        location /passwd {
            limit_req zone=passwd burst=5 nodelay;
        }
    }
}
```

```apache
# Apache rate limiting (requires mod_security)
SecRule REQUEST_URI "@contains /passwd" \
    "id:1001,phase:2,block,msg:'Rate limit exceeded',\
     setvar:'ip.passwd_requests=+1',\
     expirevar:'ip.passwd_requests=60',\
     chain"
SecRule IP:PASSWD_REQUESTS "@gt 10" \
    "block,msg:'Too many passwd requests'"
```

## Security Incident Response

### Suspicious Activity Detection
```bash
# Check for unusual access patterns
tail -f /var/log/nginx/access.log | grep passwd

# Monitor failed authentication attempts
tail -f /var/log/auth.log | grep "authentication failure"

# Check for file modifications
sudo auditctl -w /var/www/html/passwd -p wa -k passwd_access
sudo ausearch -k passwd_access
```

### Immediate Response Actions
1. **Block suspicious IPs**: `sudo ufw deny from <IP_ADDRESS>`
2. **Disable service**: `sudo systemctl stop apache2/nginx`
3. **Check file integrity**: `sudo find /var/www/html -name "passwd*" -exec ls -la {} \;`
4. **Review logs**: Check all access and error logs
5. **Update passwords**: Change all authentication credentials

### Security Audit Checklist

#### Weekly Checks
- [ ] Review access logs for unusual patterns
- [ ] Check file permissions and ownership
- [ ] Verify SSL certificate validity
- [ ] Test authentication mechanisms
- [ ] Update system packages

#### Monthly Checks
- [ ] Review firewall rules
- [ ] Audit user accounts
- [ ] Check for security updates
- [ ] Test backup and recovery procedures
- [ ] Review monitoring alerts

#### Quarterly Checks
- [ ] Full security assessment
- [ ] Penetration testing
- [ ] Review and update security policies
- [ ] Train users on security practices
- [ ] Update incident response procedures

## Production Security Recommendations

### Minimum Security Requirements
1. **Authentication**: Basic auth or better
2. **HTTPS**: SSL/TLS encryption required
3. **Firewall**: Restrict access to known IPs
4. **Logging**: Comprehensive access logging
5. **Monitoring**: Real-time alerting for suspicious activity

### Enhanced Security (Recommended)
1. **Multi-factor Authentication**: TOTP or similar
2. **VPN Access**: Require VPN connection
3. **Intrusion Detection**: IDS/IPS implementation
4. **File Integrity Monitoring**: Real-time file change detection
5. **Regular Security Audits**: Professional security assessments

### High-Security Environments
1. **Air-gapped Network**: No internet connectivity
2. **Certificate-based Authentication**: Client certificates
3. **Role-based Access Control**: Granular permissions
4. **Audit Logging**: Immutable log storage
5. **Compliance Monitoring**: SOC/compliance reporting

## Common Security Mistakes to Avoid

1. **Exposing entire /etc directory**: Only expose specific files
2. **No authentication**: Always implement access controls
3. **HTTP instead of HTTPS**: Encrypt all traffic
4. **Default credentials**: Change all default passwords
5. **Outdated software**: Keep systems updated
6. **Excessive permissions**: Follow principle of least privilege
7. **No monitoring**: Implement comprehensive logging
8. **Missing backups**: Regular backup of configurations
9. **Public access**: Restrict to necessary networks only
10. **Ignoring logs**: Regular log review and analysis