# 🚀 The Final Market - Production Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying The Final Market to production using Kamal and Docker.

## Prerequisites

- **Ruby 3.4.1** installed
- **Docker** installed and running
- **Kamal** gem installed (`gem install kamal`)
- **Production server** (Ubuntu 22.04 LTS recommended)
- **Domain name** pointing to your server IP

## Quick Start

### 1. Environment Setup

```bash
# Copy the environment template
cp .env.production.example .env.production

# Edit the file with your actual values
nano .env.production

# Load environment variables
source .env.production
```

### 2. One-Command Deployment

```bash
# Make deployment script executable
chmod +x scripts/deploy.sh

# Run full deployment
./scripts/deploy.sh
```

## Detailed Deployment Process

### Pre-deployment Checklist

- [ ] Domain name configured and pointing to server
- [ ] SSL certificate ready (handled automatically by Kamal)
- [ ] Database credentials configured
- [ ] Email service configured
- [ ] Payment gateway configured
- [ ] CDN configured (optional)
- [ ] Monitoring services configured (optional)

### Infrastructure Setup

#### Server Requirements

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Kamal
gem install kamal
```

#### Database Setup (PostgreSQL)

```bash
# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Create database user
sudo -u postgres createuser --interactive --pwprompt thefinalmarket
sudo -u postgres createdb -O thefinalmarket the_final_market_production

# Configure PostgreSQL for remote access (if needed)
sudo nano /etc/postgresql/15/main/pg_hba.conf
# Add: host    the_final_market_production    thefinalmarket    0.0.0.0/0    md5
```

#### Redis Setup

```bash
# Install Redis
sudo apt install redis-server -y

# Configure Redis (optional)
sudo nano /etc/redis/redis.conf
# Set: bind 0.0.0.0 ::1
```

### Deployment Commands

#### Initial Deployment

```bash
# Setup secrets
kamal setup

# Deploy application
kamal deploy

# Run migrations
kamal app exec "bin/rails db:migrate"

# Seed database
kamal app exec "bin/rails db:seed"
```

#### Application Management

```bash
# View logs
kamal logs

# Access console
kamal console

# SSH to server
kamal shell

# Check status
kamal status

# Restart application
kamal restart

# Rollback (if needed)
kamal rollback
```

### Environment Variables

#### Required Variables

```bash
RAILS_MASTER_KEY=your-rails-master-key
DATABASE_URL=postgresql://user:password@host:port/database
REDIS_URL=redis://host:port/database
DOMAIN_NAME=yourdomain.com
KAMAL_REGISTRY_PASSWORD=your-docker-registry-password
```

#### Optional Variables

```bash
# Email
SMTP_ADDRESS=smtp.your-provider.com
SMTP_USERNAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password

# Monitoring
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project
LOGDNA_KEY=your-logdna-key

# CDN
CDN_HOST=https://your-cdn-domain.com

# Payments
STRIPE_SECRET_KEY=sk_live_your-stripe-secret-key
SQUARE_ACCESS_TOKEN=your-square-access-token
```

## Post-deployment Tasks

### 1. SSL Certificate

Kamal automatically handles SSL certificates via Let's Encrypt. Ensure your domain points to the server IP before deployment.

### 2. DNS Configuration

Configure your DNS provider:
- **A Record**: `yourdomain.com` → `your-server-ip`
- **CNAME Record**: `www.yourdomain.com` → `yourdomain.com`

### 3. Email Verification

Test email functionality:
```bash
kamal app exec "bin/rails runner 'UserMailer.welcome_email(User.first).deliver_now'"
```

### 4. Payment Gateway Setup

Configure payment providers in the admin panel:
- Navigate to `/admin/settings`
- Configure Stripe/Square credentials
- Test payment processing

### 5. CDN Setup (Optional)

For better performance, configure a CDN:
```bash
# Update CDN_HOST in environment variables
# Configure CDN to pull from your domain
# Update asset_host in production.rb
```

## Monitoring & Maintenance

### Application Monitoring

```bash
# Check application health
curl https://yourdomain.com/up

# Monitor background jobs
kamal app exec "bin/rails solid_queue:monitor"

# View application logs
kamal logs -f
```

### Database Maintenance

```bash
# Backup database
kamal app exec "bin/rails db:backup"

# Analyze database performance
kamal app exec "bin/rails db:performance:analyze"

# Clean old data
kamal app exec "bin/rails db:cleanup:old_records"
```

### Security Updates

```bash
# Update application
kamal deploy

# Update system packages
kamal app exec "sudo apt update && sudo apt upgrade -y"

# Update Ruby gems
kamal app exec "bundle update"
```

## Troubleshooting

### Common Issues

#### Application Won't Start
```bash
# Check logs
kamal logs

# Check system resources
kamal app exec "df -h && free -h"

# Restart services
kamal restart
```

#### Database Connection Issues
```bash
# Test database connection
kamal app exec "bin/rails db:version"

# Check PostgreSQL status
kamal app exec "sudo systemctl status postgresql"
```

#### SSL Certificate Issues
```bash
# Check certificate status
kamal app exec "sudo certbot certificates"

# Renew certificate
kamal app exec "sudo certbot renew"
```

### Emergency Procedures

#### Rollback Deployment
```bash
kamal rollback
```

#### Access Server Directly
```bash
# SSH to server
kamal shell

# Check Docker containers
sudo docker ps -a

# Check system logs
sudo journalctl -u docker -f
```

## Performance Optimization

### Application Level

```bash
# Precompile assets
kamal app exec "bin/rails assets:precompile"

# Enable caching
kamal app exec "bin/rails cache:clear"

# Optimize database
kamal app exec "bin/rails db:migrate:optimize"
```

### Infrastructure Level

```bash
# Monitor resource usage
kamal app exec "htop"

# Setup log rotation
kamal app exec "sudo logrotate -f /etc/logrotate.conf"

# Configure swap (if needed)
kamal app exec "sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
```

## Support

For issues and questions:
1. Check the logs: `kamal logs`
2. Review this documentation
3. Check Kamal documentation: https://kamal-deploy.org
4. Open an issue in the project repository

## Security Notes

- Keep your `.env.production` file secure and never commit it to version control
- Regularly update dependencies and security patches
- Monitor logs for suspicious activity
- Use strong, unique passwords for all services
- Enable 2FA where possible
- Regularly backup your data

---

**🎉 Congratulations! Your marketplace is now live and ready for the world!**

Visit your application at `https://yourdomain.com` and start building your marketplace empire! 🚀