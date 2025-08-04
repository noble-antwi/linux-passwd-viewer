#!/bin/bash

# Linux passwd File Viewer - Auto-Update Setup Script
# This script helps you set up automatic updating for your passwd file viewer

set -e

echo "🐧 Linux passwd File Viewer - Auto-Update Setup"
echo "================================================"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Warning: Running as root. Consider running as a regular user for security."
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install packages
install_package() {
    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y "$1"
    elif command_exists yum; then
        sudo yum install -y "$1"
    elif command_exists dnf; then
        sudo dnf install -y "$1"
    elif command_exists pacman; then
        sudo pacman -S --noconfirm "$1"
    else
        echo "❌ Unable to install $1. Please install it manually."
        exit 1
    fi
}

# Menu function
show_menu() {
    echo "Choose your setup option:"
    echo "1. Simple Python HTTP Server (Copy Method)"
    echo "2. Apache Web Server Setup (Copy Method)"
    echo "3. Nginx Web Server Setup (Copy Method)"
    echo "4. File Watcher with Auto-Copy"
    echo "5. Systemd Service for Auto-Update"
    echo "6. Direct File Monitoring - Apache"
    echo "7. Direct File Monitoring - Nginx"
    echo "8. Symbolic Link Method (Safer Direct Access)"
    echo "9. Docker Container Setup"
    echo "10. Just show me the commands"
    echo "0. Exit"
    echo
    read -p "Enter your choice (0-10): " choice
}

# Python HTTP Server setup
setup_python_server() {
    echo "🐍 Setting up Python HTTP Server..."
    
    if ! command_exists python3; then
        echo "Installing Python 3..."
        install_package python3
    fi
    
    # Create a safe directory for serving files
    SERVE_DIR="$HOME/passwd-viewer"
    mkdir -p "$SERVE_DIR"
    
    # Copy passwd file
    cp /etc/passwd "$SERVE_DIR/passwd"
    chmod 644 "$SERVE_DIR/passwd"
    
    # Create update script
    cat > "$SERVE_DIR/update-passwd.sh" << 'EOF'
#!/bin/bash
cp /etc/passwd /home/$USER/passwd-viewer/passwd
chmod 644 /home/$USER/passwd-viewer/passwd
echo "$(date): passwd file updated"
EOF
    
    chmod +x "$SERVE_DIR/update-passwd.sh"
    
    echo "✅ Setup complete!"
    echo "📁 Files created in: $SERVE_DIR"
    echo "🚀 To start the server:"
    echo "   cd $SERVE_DIR && python3 -m http.server 8080"
    echo "🌐 Then use URL: http://localhost:8080/passwd"
    echo "🔄 To update manually: $SERVE_DIR/update-passwd.sh"
}

# Apache setup
setup_apache() {
    echo "🌐 Setting up Apache Web Server..."
    
    if ! command_exists apache2 && ! command_exists httpd; then
        echo "Installing Apache..."
        if command_exists apt-get; then
            install_package apache2
            APACHE_DIR="/var/www/html"
            APACHE_SERVICE="apache2"
        else
            install_package httpd
            APACHE_DIR="/var/www/html"
            APACHE_SERVICE="httpd"
        fi
    else
        if command_exists apache2; then
            APACHE_DIR="/var/www/html"
            APACHE_SERVICE="apache2"
        else
            APACHE_DIR="/var/www/html"
            APACHE_SERVICE="httpd"
        fi
    fi
    
    # Copy passwd file
    sudo cp /etc/passwd "$APACHE_DIR/passwd"
    sudo chmod 644 "$APACHE_DIR/passwd"
    
    # Create CORS configuration
    cat > /tmp/passwd-cors.conf << 'EOF'
<Files "passwd">
    Header always set Access-Control-Allow-Origin "*"
    Header always set Access-Control-Allow-Methods "GET, OPTIONS"
    Header always set Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept"
</Files>
EOF
    
    sudo cp /tmp/passwd-cors.conf /etc/apache2/conf-available/ 2>/dev/null || \
    sudo cp /tmp/passwd-cors.conf /etc/httpd/conf.d/ 2>/dev/null || true
    
    # Enable modules and configuration
    sudo a2enmod headers 2>/dev/null || true
    sudo a2enconf passwd-cors 2>/dev/null || true
    
    # Restart Apache
    sudo systemctl restart $APACHE_SERVICE
    sudo systemctl enable $APACHE_SERVICE
    
    echo "✅ Apache setup complete!"
    echo "🌐 Your passwd file is available at: http://localhost/passwd"
    echo "🔄 To update: sudo cp /etc/passwd $APACHE_DIR/passwd"
}

# Nginx setup
setup_nginx() {
    echo "🌐 Setting up Nginx Web Server..."
    
    if ! command_exists nginx; then
        echo "Installing Nginx..."
        install_package nginx
    fi
    
    NGINX_DIR="/var/www/html"
    sudo mkdir -p "$NGINX_DIR"
    
    # Copy passwd file
    sudo cp /etc/passwd "$NGINX_DIR/passwd"
    sudo chmod 644 "$NGINX_DIR/passwd"
    
    # Create Nginx configuration
    cat > /tmp/passwd-nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    
    location /passwd {
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept";
        
        if ($request_method = 'OPTIONS') {
            return 204;
        }
    }
}
EOF
    
    sudo cp /tmp/passwd-nginx.conf /etc/nginx/sites-available/passwd-viewer
    sudo ln -sf /etc/nginx/sites-available/passwd-viewer /etc/nginx/sites-enabled/
    
    # Test and restart Nginx
    sudo nginx -t
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    
    echo "✅ Nginx setup complete!"
    echo "🌐 Your passwd file is available at: http://localhost/passwd"
    echo "🔄 To update: sudo cp /etc/passwd $NGINX_DIR/passwd"
}

# File watcher setup
setup_file_watcher() {
    echo "👁️  Setting up File Watcher..."
    
    if ! command_exists inotifywait; then
        echo "Installing inotify-tools..."
        install_package inotify-tools
    fi
    
    # Choose destination directory
    read -p "Enter destination directory for passwd file [/var/www/html]: " DEST_DIR
    DEST_DIR=${DEST_DIR:-/var/www/html}
    
    # Create watcher script
    cat > "$HOME/passwd-watcher.sh" << EOF
#!/bin/bash

DEST_DIR="$DEST_DIR"
LOG_FILE="\$HOME/passwd-watcher.log"

echo "\$(date): Starting passwd file watcher..." >> "\$LOG_FILE"

# Initial copy
cp /etc/passwd "\$DEST_DIR/passwd" 2>/dev/null && chmod 644 "\$DEST_DIR/passwd" 2>/dev/null || {
    echo "\$(date): Error: Cannot write to \$DEST_DIR. Check permissions." >> "\$LOG_FILE"
    exit 1
}

# Watch for changes
inotifywait -m /etc/passwd -e modify --format '%w%f %e %T' --timefmt '%Y-%m-%d %H:%M:%S' | while read file event time; do
    echo "\$time: Detected \$event on \$file" >> "\$LOG_FILE"
    
    # Copy with error handling
    if cp /etc/passwd "\$DEST_DIR/passwd" 2>/dev/null && chmod 644 "\$DEST_DIR/passwd" 2>/dev/null; then
        echo "\$time: Successfully updated \$DEST_DIR/passwd" >> "\$LOG_FILE"
    else
        echo "\$time: Error updating \$DEST_DIR/passwd" >> "\$LOG_FILE"
    fi
done
EOF
    
    chmod +x "$HOME/passwd-watcher.sh"
    
    echo "✅ File watcher setup complete!"
    echo "🚀 To start manually: $HOME/passwd-watcher.sh"
    echo "📋 Log file: $HOME/passwd-watcher.log"
    echo "💡 Consider setting up as a systemd service (option 5)"
}

# Systemd service setup
setup_systemd_service() {
    echo "⚙️  Setting up Systemd Service..."
    
    # First set up the file watcher if not exists
    if [ ! -f "$HOME/passwd-watcher.sh" ]; then
        setup_file_watcher
    fi
    
    # Create systemd service
    cat > /tmp/passwd-watcher.service << EOF
[Unit]
Description=Linux passwd File Watcher
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$HOME/passwd-watcher.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    sudo cp /tmp/passwd-watcher.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable passwd-watcher.service
    sudo systemctl start passwd-watcher.service
    
    echo "✅ Systemd service setup complete!"
    echo "📊 Check status: sudo systemctl status passwd-watcher"
    echo "📜 View logs: sudo journalctl -u passwd-watcher -f"
    echo "🛑 Stop service: sudo systemctl stop passwd-watcher"
}

# Docker setup
setup_docker() {
    echo "🐳 Setting up Docker Container..."
    
    if ! command_exists docker; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        echo "⚠️  Please log out and back in to use Docker without sudo"
    fi
    
    # Create Dockerfile
    cat > /tmp/Dockerfile << 'EOF'
FROM nginx:alpine

# Install inotify-tools
RUN apk add --no-cache inotify-tools

# Copy initial passwd file
COPY passwd /usr/share/nginx/html/passwd

# Create nginx configuration
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    root /usr/share/nginx/html; \
    location /passwd { \
        add_header Access-Control-Allow-Origin *; \
        add_header Access-Control-Allow-Methods "GET, OPTIONS"; \
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept"; \
        if ($request_method = OPTIONS) { return 204; } \
    } \
}' > /etc/nginx/conf.d/default.conf

# Start script
RUN echo '#!/bin/sh \
nginx -g "daemon off;" & \
while inotifywait -e modify /host/etc/passwd; do \
    cp /host/etc/passwd /usr/share/nginx/html/passwd \
    echo "$(date): passwd file updated" \
done' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
EOF
    
    # Build and run
    cp /etc/passwd /tmp/passwd
    cd /tmp
    sudo docker build -t passwd-viewer .
    
    echo "✅ Docker setup complete!"
    echo "🚀 To run: sudo docker run -d -p 8080:80 -v /etc:/host/etc:ro passwd-viewer"
    echo "🌐 Then use URL: http://localhost:8080/passwd"
}

# Apache direct file monitoring
setup_apache_direct() {
    echo "🔴 Setting up Apache DIRECT File Monitoring..."
    echo "⚠️  WARNING: This exposes /etc directory via web!"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Setup cancelled."
        return
    fi
    
    if ! command_exists apache2 && ! command_exists httpd; then
        echo "Installing Apache..."
        install_package apache2 || install_package httpd
    fi
    
    # Create direct access configuration
    cat > /tmp/direct-access.conf << 'EOF'
# Direct /etc access - USE WITH CAUTION!
Alias /etc /etc
<Directory "/etc">
    Require all granted
    Options Indexes FollowSymLinks
    AllowOverride None
    Header always set Access-Control-Allow-Origin "*"
    Header always set Access-Control-Allow-Methods "GET, OPTIONS"
    Header always set Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept"
</Directory>
EOF
    
    # Install configuration
    if [ -d "/etc/apache2/conf-available" ]; then
        sudo cp /tmp/direct-access.conf /etc/apache2/conf-available/
        sudo a2enmod headers
        sudo a2enconf direct-access
        sudo systemctl reload apache2
    else
        sudo cp /tmp/direct-access.conf /etc/httpd/conf.d/
        sudo systemctl reload httpd
    fi
    
    echo "✅ Apache direct access setup complete!"
    echo "🌐 Access passwd file at: http://localhost/etc/passwd"
    echo "⚠️  SECURITY: This exposes ALL /etc files!"
    echo "💡 Consider using option 8 (Symbolic Link) for better security"
}

# Nginx direct file monitoring
setup_nginx_direct() {
    echo "🔴 Setting up Nginx DIRECT File Monitoring..."
    echo "⚠️  WARNING: This exposes /etc directory via web!"
    echo
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Setup cancelled."
        return
    fi
    
    if ! command_exists nginx; then
        echo "Installing Nginx..."
        install_package nginx
    fi
    
    # Backup current configuration
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    
    # Create direct access configuration
    cat > /tmp/nginx-direct.conf << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    root /var/www/html;
    index index.html index.htm;
    server_name _;
    
    # Direct /etc access - USE WITH CAUTION!
    location /etc/ {
        alias /etc/;
        autoindex on;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
        add_header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept";
        
        if ($request_method = 'OPTIONS') {
            return 204;
        }
    }
    
    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
    
    sudo cp /tmp/nginx-direct.conf /etc/nginx/sites-available/default
    sudo nginx -t && sudo systemctl reload nginx
    
    echo "✅ Nginx direct access setup complete!"
    echo "🌐 Access passwd file at: http://localhost/etc/passwd"
    echo "⚠️  SECURITY: This exposes ALL /etc files!"
    echo "💡 Consider using option 8 (Symbolic Link) for better security"
}

# Symbolic link method (safer direct access)
setup_symbolic_link() {
    echo "🔗 Setting up Symbolic Link Method..."
    
    WEBROOT="/var/www/html"
    
    # Determine web server and root
    if command_exists apache2 || command_exists httpd; then
        WEBROOT="/var/www/html"
    elif command_exists nginx; then
        WEBROOT="/var/www/html"
    else
        read -p "Enter your web root directory [$WEBROOT]: " custom_root
        WEBROOT=${custom_root:-$WEBROOT}
    fi
    
    # Create symbolic links
    sudo ln -sf /etc/passwd "$WEBROOT/passwd-live"
    sudo ln -sf /etc/group "$WEBROOT/group-live"
    sudo ln -sf /etc/shadow "$WEBROOT/shadow-live" 2>/dev/null || echo "Note: shadow file not linked (requires root)"
    
    # Set proper permissions
    sudo chmod 644 "$WEBROOT/passwd-live" 2>/dev/null || true
    
    # Configure CORS for the linked files
    if command_exists apache2; then
        cat > /tmp/symlink-cors.conf << 'EOF'
<Files "*-live">
    Header always set Access-Control-Allow-Origin "*"
    Header always set Access-Control-Allow-Methods "GET, OPTIONS"
    Header always set Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept"
</Files>
EOF
        sudo cp /tmp/symlink-cors.conf /etc/apache2/conf-available/
        sudo a2enmod headers 2>/dev/null
        sudo a2enconf symlink-cors 2>/dev/null
        sudo systemctl reload apache2
    fi
    
    echo "✅ Symbolic link setup complete!"
    echo "🔗 Symbolic links created:"
    echo "   📄 $WEBROOT/passwd-live -> /etc/passwd"
    echo "   📄 $WEBROOT/group-live -> /etc/group"
    echo "🌐 Use URL: http://localhost/passwd-live"
    echo "✅ This method is safer than full /etc access"
    echo "💡 Links automatically reflect file changes!"
}

# Show commands only
show_commands() {
    echo "📋 Quick Command Reference:"
    echo
    echo "1. Python HTTP Server:"
    echo "   mkdir ~/passwd-viewer && cp /etc/passwd ~/passwd-viewer/"
    echo "   cd ~/passwd-viewer && python3 -m http.server 8080"
    echo
    echo "2. File Watcher:"
    echo "   sudo apt install inotify-tools"
    echo "   inotifywait -m /etc/passwd -e modify --format '%w%f' | while read file; do"
    echo "     cp \"\$file\" /var/www/html/passwd"
    echo "   done"
    echo
    echo "3. Cron Job (every minute):"
    echo "   echo '* * * * * cp /etc/passwd /var/www/html/passwd' | crontab -"
    echo
    echo "4. Apache CORS:"
    echo "   echo 'Header set Access-Control-Allow-Origin \"*\"' | sudo tee /etc/apache2/conf-available/cors.conf"
    echo "   sudo a2enmod headers && sudo a2enconf cors && sudo systemctl reload apache2"
    echo
}

# Main execution
main() {
    while true; do
        show_menu
        case $choice in
            1) setup_python_server ;;
            2) setup_apache ;;
            3) setup_nginx ;;
            4) setup_file_watcher ;;
            5) setup_systemd_service ;;
            6) setup_apache_direct ;;
            7) setup_nginx_direct ;;
            8) setup_symbolic_link ;;
            9) setup_docker ;;
            10) show_commands ;;
            0) echo "👋 Goodbye!"; exit 0 ;;
            *) echo "❌ Invalid option. Please try again." ;;
        esac
        echo
        read -p "Press Enter to continue or Ctrl+C to exit..."
        echo
    done
}

# Check for help flag
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--help]"
    echo
    echo "This script helps you set up automatic updating for the Linux passwd file viewer."
    echo "It provides multiple options for serving and auto-updating your passwd file."
    echo
    exit 0
fi

# Run main function
main