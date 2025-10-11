# Advanced Mobile App - Quick Setup Guide

## 🚀 Quick Start (5 Minutes)

### Step 1: Run Database Migration

```bash
rails db:migrate
```

This creates the necessary tables for:
- Barcode scans
- Push subscriptions
- Mobile devices
- Product suggestions
- Stores and deals
- Offline sync queue

### Step 2: Update User Model

Add to `app/models/user.rb`:

```ruby
# Mobile app associations
has_many :barcode_scans, dependent: :destroy
has_many :push_subscriptions, dependent: :destroy
has_many :mobile_devices, dependent: :destroy
has_many :offline_sync_actions, dependent: :destroy
```

### Step 3: Configure API Keys

```bash
rails credentials:edit
```

Add minimum configuration:

```yaml
# Optional: Barcode lookup (for external product database)
barcode_lookup:
  api_key: your_api_key_here

# Optional: Google Vision (for visual search)
google_vision:
  api_key: your_google_vision_api_key

# Optional: Apple Pay
apple_pay:
  merchant_id: merchant.com.yourcompany
  domain: yourdomain.com

# Optional: Google Pay
google_pay:
  merchant_id: your_merchant_id
```

### Step 4: Test Basic Features

Start your Rails server with HTTPS (required for mobile features):

```bash
# Option 1: Use ngrok (easiest for testing)
rails s
# In another terminal:
ngrok http 3000

# Option 2: Local SSL
rails s -b 'ssl://localhost:3000?key=localhost.key&cert=localhost.crt'
```

### Step 5: Test on Mobile Device

1. Open your app URL on a mobile device
2. Test barcode scanner: `/mobile/scanner`
3. Test camera features: `/mobile/camera`
4. Test geolocation: `/mobile/nearby`

## 📱 Feature-by-Feature Setup

### Barcode Scanner

**No additional setup required!** Works out of the box with:
- Local product database lookup
- Price comparison across sellers
- Scan history tracking

**Optional Enhancement:**
Add external barcode API for products not in your database:

```yaml
# config/credentials.yml.enc
barcode_lookup:
  api_key: get_from_barcodelookup.com
```

### Visual Search

**Basic Setup:** Works with local product matching

**Enhanced Setup:** Add Google Vision API for AI-powered search:

```yaml
# config/credentials.yml.enc
google_vision:
  api_key: get_from_console.cloud.google.com
```

### Biometric Authentication

**No setup required!** Uses WebAuthn standard supported by:
- iOS Safari (Face ID/Touch ID)
- Android Chrome (Fingerprint)
- Desktop browsers (Windows Hello, etc.)

### Mobile Wallet

**Apple Pay Setup:**

1. Create Apple Merchant ID at developer.apple.com
2. Generate merchant certificate
3. Add to credentials:

```yaml
apple_pay:
  merchant_id: merchant.com.yourcompany
  domain: yourdomain.com
  certificate_path: config/certs/apple_pay.pem
```

**Google Pay Setup:**

1. Register at pay.google.com/business/console
2. Add to credentials:

```yaml
google_pay:
  merchant_id: your_merchant_id
  merchant_name: TheFinalMarket
```

### Geolocation Features

**No setup required!** Uses:
- Browser Geolocation API
- OpenStreetMap for geocoding (free)

**Optional:** Add Google Maps API for enhanced features:

```yaml
google_maps:
  api_key: your_google_maps_api_key
```

### Offline Mode

**No setup required!** Uses:
- Service Workers (already configured)
- IndexedDB (browser built-in)
- Cache API (browser built-in)

### Push Notifications

**Already configured!** Your app already has:
- VAPID keys
- Service Worker
- Push notification service

Just ensure users grant notification permission.

## 🧪 Testing Checklist

### Barcode Scanner
- [ ] Camera permission granted
- [ ] Barcode detected and scanned
- [ ] Product found in database
- [ ] Price comparison shown
- [ ] Scan saved to history

### Visual Search
- [ ] Camera access working
- [ ] Photo captured successfully
- [ ] Similar products found
- [ ] Results displayed correctly

### Biometric Auth
- [ ] Device supports biometrics
- [ ] Enrollment successful
- [ ] Authentication works
- [ ] Login redirects correctly

### Mobile Wallet
- [ ] Apple Pay button shows (iOS)
- [ ] Google Pay button shows (Android)
- [ ] Payment sheet opens
- [ ] Payment processes successfully
- [ ] Order confirmed

### Geolocation
- [ ] Location permission granted
- [ ] Current location detected
- [ ] Nearby stores found
- [ ] Distance calculated correctly
- [ ] Geofence alerts working

### Offline Mode
- [ ] Products cached for offline
- [ ] Cart works offline
- [ ] Actions queued when offline
- [ ] Auto-sync when online
- [ ] Sync status displayed

### Push Notifications
- [ ] Permission requested
- [ ] Subscription registered
- [ ] Test notification received
- [ ] Notification clicked opens app

## 🔧 Troubleshooting

### "Camera not working"
**Solution:** Ensure HTTPS is enabled. Mobile browsers require secure context for camera access.

```bash
# Use ngrok for easy HTTPS testing
ngrok http 3000
```

### "Geolocation permission denied"
**Solution:** Check browser settings and ensure HTTPS. Some browsers block geolocation on HTTP.

### "Biometric auth not available"
**Solution:** 
- Ensure device has biometric hardware
- Check browser supports WebAuthn
- Verify HTTPS connection

### "Service Worker not registering"
**Solution:**
- Check browser console for errors
- Ensure `/service-worker.js` is accessible
- Verify HTTPS connection

### "Push notifications not working"
**Solution:**
- Check VAPID keys are configured
- Verify notification permission granted
- Test with `/api/mobile/test-notification`

## 📊 Monitoring & Analytics

### Track Mobile Feature Usage

Add to your analytics:

```javascript
// Track barcode scans
document.addEventListener('barcode:product-found', (event) => {
  analytics.track('Barcode Scanned', {
    product_id: event.detail.id,
    barcode: event.detail.barcode
  })
})

// Track visual searches
document.addEventListener('camera:search-results', (event) => {
  analytics.track('Visual Search', {
    results_count: event.detail.products.length
  })
})

// Track biometric usage
document.addEventListener('biometric:authenticated', () => {
  analytics.track('Biometric Login')
})

// Track mobile wallet usage
document.addEventListener('wallet:payment-success', (event) => {
  analytics.track('Mobile Wallet Payment', {
    method: event.detail.payment_method,
    amount: event.detail.amount
  })
})
```

## 🎨 Customization

### Style Mobile Components

Create `app/assets/stylesheets/mobile.css`:

```css
/* Barcode scanner overlay */
.barcode-scanner-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.8);
}

.scan-line {
  height: 2px;
  background: #00ff00;
  animation: scan 2s linear infinite;
}

/* Mobile wallet buttons */
.apple-pay-button {
  -webkit-appearance: -apple-pay-button;
  -apple-pay-button-type: buy;
  height: 44px;
}

.google-pay-button {
  background: #000;
  color: #fff;
  border-radius: 4px;
  height: 44px;
}

/* Offline indicator */
.offline-indicator {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  background: #ff9800;
  color: #fff;
  padding: 8px;
  text-align: center;
  z-index: 9999;
}
```

## 🚀 Production Deployment

### Pre-Deployment Checklist

- [ ] HTTPS enabled on production domain
- [ ] API keys configured in production credentials
- [ ] Service Worker registered correctly
- [ ] Push notification VAPID keys set
- [ ] Apple Pay merchant verified
- [ ] Google Pay merchant approved
- [ ] Geolocation privacy policy updated
- [ ] Camera usage explained in UI
- [ ] Offline mode tested thoroughly

### Performance Optimization

```ruby
# config/environments/production.rb

# Enable asset compression
config.assets.compress = true

# Enable CDN for assets
config.asset_host = 'https://cdn.yourdomain.com'

# Cache mobile API responses
config.action_controller.perform_caching = true
```

### Security Hardening

```ruby
# config/initializers/mobile_security.rb

# Rate limit mobile API endpoints
Rails.application.config.middleware.use Rack::Attack

Rack::Attack.throttle('mobile_api', limit: 100, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/api/mobile')
end

# Require HTTPS for mobile features
Rails.application.config.force_ssl = true
```

## 📈 Next Steps

1. **Add Mobile Views**: Create dedicated mobile-optimized pages
2. **Implement PWA**: Add to home screen functionality
3. **Create Mobile App**: Wrap in Capacitor/Cordova for native apps
4. **Add Analytics**: Track mobile feature adoption
5. **A/B Test**: Test different mobile experiences
6. **Optimize Performance**: Lazy load features, compress images
7. **Add More AR Features**: 3D product models, virtual try-on
8. **Geofence Campaigns**: Location-based marketing

## 🆘 Support

Need help? Check:
- [Mobile App Guide](MOBILE_APP_GUIDE.md) - Detailed feature documentation
- Browser console for errors
- Network tab for API issues
- Service Worker status in DevTools

## 🎉 You're Ready!

Your mobile app features are now set up and ready to use. Test each feature on a real mobile device to ensure everything works as expected.

Happy coding! 📱✨

