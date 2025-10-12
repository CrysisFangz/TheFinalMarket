# Advanced Performance Optimization - Setup Guide

## Quick Start

### 1. Run Setup Script

```bash
bin/setup_performance
```

This will:
- Install required gems
- Check Redis connection
- Check PostgreSQL connection
- Verify image processing dependencies
- Create GraphQL schema dump

---

## Prerequisites

### Required Software

1. **Ruby 3.x+**
   ```bash
   ruby --version
   ```

2. **PostgreSQL 14+**
   ```bash
   psql --version
   ```

3. **Redis 6+**
   ```bash
   redis-cli --version
   ```

4. **libvips** (for image processing)
   ```bash
   # macOS
   brew install vips
   
   # Ubuntu/Debian
   apt-get install libvips-dev
   
   # Verify
   vips --version
   ```

---

## Installation Steps

### Step 1: Install Dependencies

```bash
bundle install
```

### Step 2: Configure Environment Variables

Create a `.env` file or add to Rails credentials:

```bash
# Redis
REDIS_URL=redis://localhost:6379/0

# CDN (Optional - for production)
CDN_HOST=https://cdn.thefinalmarket.com
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token
CLOUDFLARE_ZONE_ID=your_cloudflare_zone_id

# Database Sharding (Optional - for production)
SHARD_1_DB_HOST=localhost
SHARD_1_DB_PORT=5432
SHARD_1_DB_USERNAME=postgres
SHARD_1_DB_PASSWORD=

# Repeat for shards 2-4...
```

### Step 3: Start Redis

```bash
# macOS
brew services start redis

# Linux
sudo systemctl start redis

# Verify
redis-cli ping
# Should return: PONG
```

### Step 4: Database Setup

```bash
# Create databases
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Seed data (optional)
bin/rails db:seed
```

### Step 5: Start the Server

```bash
bin/rails server
```

---

## Testing the Features

### 1. Test GraphQL API

Visit `http://localhost:3000/graphiql` in your browser.

Try this query:
```graphql
query {
  categories {
    id
    name
    productsCount
  }
}
```

See `GRAPHQL_EXAMPLES.md` for more examples.

### 2. Test PWA Features

1. Open Chrome DevTools (F12)
2. Go to "Application" tab
3. Check "Service Workers" - should show registered worker
4. Check "Cache Storage" - should show caches
5. Go offline (Network tab → Offline)
6. Reload page - should work offline

### 3. Test Real-Time Updates

1. Open product page
2. Open browser console
3. Update product stock in another tab/window
4. Watch for real-time updates in console and UI

### 4. Test Image Optimization

1. Upload a product image
2. Check generated variants:
   - Thumbnail (150x150)
   - Small (300x300)
   - Medium (600x600)
   - Large (1200x1200)
   - WebP versions
   - Blur placeholder

### 5. Test Mobile Optimizations

1. Open Chrome DevTools
2. Toggle device toolbar (Ctrl+Shift+M)
3. Select a mobile device
4. Test:
   - Touch gestures
   - Swipe navigation
   - Pull-to-refresh
   - Responsive images

---

## Performance Testing

### Lighthouse Audit

1. Open Chrome DevTools
2. Go to "Lighthouse" tab
3. Select categories:
   - Performance
   - Accessibility
   - Best Practices
   - SEO
   - PWA
4. Click "Generate report"

Target scores:
- Performance: 90+
- Accessibility: 100
- Best Practices: 100
- SEO: 100
- PWA: 100

### WebPageTest

1. Visit https://www.webpagetest.org/
2. Enter your URL
3. Select test location
4. Run test
5. Review:
   - First Byte Time
   - Start Render
   - Speed Index
   - Largest Contentful Paint

### Load Testing

```bash
# Install Apache Bench
brew install httpd

# Test API endpoint
ab -n 1000 -c 10 http://localhost:3000/api/products

# Test GraphQL endpoint
ab -n 1000 -c 10 -p graphql_query.json -T application/json http://localhost:3000/graphql
```

---

## Production Deployment

### 1. CDN Setup (CloudFlare)

1. Sign up at https://cloudflare.com
2. Add your domain
3. Update DNS records
4. Enable caching:
   - Go to "Caching" → "Configuration"
   - Set "Caching Level" to "Standard"
   - Enable "Auto Minify" for HTML, CSS, JS
5. Get API credentials:
   - Go to "My Profile" → "API Tokens"
   - Create token with "Zone.Cache Purge" permission
6. Add to environment variables

### 2. Database Sharding Setup

1. Create shard databases:
   ```bash
   createdb thefinalmarket_shard_1
   createdb thefinalmarket_shard_2
   createdb thefinalmarket_shard_3
   createdb thefinalmarket_shard_4
   ```

2. Run migrations on each shard:
   ```bash
   RAILS_ENV=production bin/rails db:migrate
   ```

3. Configure connection pooling (PgBouncer):
   ```ini
   # /etc/pgbouncer/pgbouncer.ini
   [databases]
   thefinalmarket_shard_1 = host=localhost port=5432 dbname=thefinalmarket_shard_1
   thefinalmarket_shard_2 = host=localhost port=5432 dbname=thefinalmarket_shard_2
   
   [pgbouncer]
   pool_mode = transaction
   max_client_conn = 1000
   default_pool_size = 25
   ```

### 3. Redis Setup

```bash
# Install Redis
brew install redis

# Configure for production
# Edit /usr/local/etc/redis.conf
maxmemory 2gb
maxmemory-policy allkeys-lru

# Start Redis
brew services start redis
```

### 4. Image Storage (S3/CloudFlare R2)

Update `config/storage.yml`:

```yaml
production:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: us-east-1
  bucket: thefinalmarket-production
```

### 5. Environment Variables

Set in production:

```bash
# Heroku
heroku config:set REDIS_URL=redis://...
heroku config:set CDN_HOST=https://cdn.thefinalmarket.com

# Or in .env.production
RAILS_ENV=production
REDIS_URL=redis://production-redis:6379/0
CDN_HOST=https://cdn.thefinalmarket.com
CLOUDFLARE_API_TOKEN=...
CLOUDFLARE_ZONE_ID=...
```

---

## Monitoring

### Application Performance Monitoring

1. **New Relic** (recommended)
   ```ruby
   # Gemfile
   gem 'newrelic_rpm'
   ```

2. **Skylight**
   ```ruby
   # Gemfile
   gem 'skylight'
   ```

### Error Tracking

1. **Sentry**
   ```ruby
   # Gemfile
   gem 'sentry-ruby'
   gem 'sentry-rails'
   ```

### Uptime Monitoring

- Pingdom
- UptimeRobot
- StatusCake

---

## Troubleshooting

### GraphQL Not Working

```bash
# Check if GraphQL gem is installed
bundle list | grep graphql

# Regenerate schema
bin/rails graphql:schema:dump

# Check routes
bin/rails routes | grep graphql
```

### Service Worker Not Registering

1. Check HTTPS (required for service workers)
2. Check browser console for errors
3. Verify service worker file is accessible
4. Clear browser cache and reload

### Redis Connection Failed

```bash
# Check if Redis is running
redis-cli ping

# Start Redis
brew services start redis

# Check connection
redis-cli -h localhost -p 6379
```

### Image Processing Errors

```bash
# Check libvips installation
vips --version

# Reinstall if needed
brew reinstall vips

# Check Ruby bindings
ruby -e "require 'vips'; puts Vips::VERSION"
```

### Database Sharding Issues

```bash
# Check shard health
bin/rails runner "puts DatabaseSharding.check_all_shards_health"

# Get shard statistics
bin/rails runner "puts DatabaseSharding.all_shards_statistics"
```

---

## Best Practices

### GraphQL

1. Always use DataLoader for associations
2. Limit query depth to prevent abuse
3. Use pagination for large lists
4. Cache frequently accessed data
5. Monitor query complexity

### Caching

1. Use fragment caching in views
2. Cache expensive computations
3. Set appropriate expiration times
4. Use cache versioning
5. Monitor cache hit rates

### Images

1. Always generate WebP versions
2. Use lazy loading for below-the-fold images
3. Provide blur placeholders
4. Use responsive images with srcset
5. Optimize image quality (85% is usually good)

### Mobile

1. Test on real devices
2. Optimize for touch (44x44px minimum)
3. Use mobile-first CSS
4. Minimize JavaScript
5. Enable offline support

---

## Additional Resources

- **Documentation**
  - PERFORMANCE_OPTIMIZATION_GUIDE.md
  - PERFORMANCE_OPTIMIZATION_SUMMARY.md
  - GRAPHQL_EXAMPLES.md

- **External Resources**
  - [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
  - [PWA Checklist](https://web.dev/pwa-checklist/)
  - [Web Performance](https://web.dev/performance/)
  - [CloudFlare Docs](https://developers.cloudflare.com/)

---

## Support

For issues or questions:
1. Check the documentation files
2. Review error logs: `log/production.log`
3. Check Redis logs: `redis-cli monitor`
4. Check PostgreSQL logs
5. Review browser console for client-side errors

---

**Advanced Performance Optimization System v1.0**
Built for The Final Market with ❤️

