# Advanced Mobile App Features Guide

## Overview

TheFinalMarket's Advanced Mobile App provides a native-like mobile experience with cutting-edge features including barcode scanning, visual search, AR try-on, biometric authentication, mobile wallet integration, geolocation features, and offline mode.

## Features

### 1. 📱 Barcode Scanner

Scan product barcodes in-store to instantly compare prices and find the best deals.

**Features:**
- Real-time barcode detection using device camera
- Support for multiple barcode formats (UPC, EAN, QR codes, etc.)
- Instant price comparison across sellers
- Scan history tracking
- Product lookup from external databases
- In-store price matching

**Usage:**

```javascript
// HTML
<div data-controller="barcode-scanner">
  <video data-barcode-scanner-target="video"></video>
  <canvas data-barcode-scanner-target="canvas" class="hidden"></canvas>
  <div data-barcode-scanner-target="result"></div>
  <button data-action="click->barcode-scanner#startScanning">Scan Barcode</button>
</div>

// The controller automatically:
// 1. Requests camera permission
// 2. Detects barcodes in real-time
// 3. Looks up product information
// 4. Compares prices across sellers
// 5. Saves scan history
```

**API Endpoints:**
- `POST /api/mobile/barcode/scan` - Scan and lookup product
- `POST /api/mobile/barcode/compare` - Compare prices

### 2. 📸 Camera Integration & Visual Search

Search for products by taking a photo - perfect for finding items you see in real life.

**Features:**
- Visual product search using AI
- Image-based product matching
- AR try-on for fashion and accessories
- Camera switching (front/back)
- Photo capture and preview
- Product information extraction from images

**Usage:**

```javascript
// HTML
<div data-controller="camera">
  <video data-camera-target="video"></video>
  <canvas data-camera-target="canvas" class="hidden"></canvas>
  <img data-camera-target="preview" class="hidden">
  
  <button data-action="click->camera#startCamera">Start Camera</button>
  <button data-action="click->camera#visualSearch">Search by Image</button>
  <button data-action="click->camera#switchCamera">Switch Camera</button>
  <button data-action="click->camera#startAR">Try On (AR)</button>
</div>

// Listen for events
document.addEventListener('camera:search-results', (event) => {
  console.log('Found products:', event.detail.products)
})
```

**API Endpoints:**
- `POST /api/mobile/visual-search` - Search by image
- `POST /api/mobile/extract-product-info` - Extract product details from image

### 3. 🔐 Biometric Authentication

Secure, passwordless login using Face ID or fingerprint.

**Features:**
- Face ID support (iOS)
- Fingerprint authentication (iOS/Android)
- WebAuthn/FIDO2 standard
- Secure credential storage
- Quick payment authorization
- Platform authenticator integration

**Usage:**

```javascript
// HTML
<div data-controller="biometric-auth">
  <div data-biometric-auth-target="status"></div>
  
  <button data-biometric-auth-target="enrollButton" 
          data-action="click->biometric-auth#enroll">
    Enable Biometric Login
  </button>
  
  <button data-biometric-auth-target="authenticateButton"
          data-action="click->biometric-auth#authenticate">
    Login with Biometrics
  </button>
</div>

// Listen for events
document.addEventListener('biometric:authenticated', (event) => {
  console.log('User authenticated:', event.detail)
})
```

**API Endpoints:**
- `POST /api/mobile/biometric/enroll/challenge` - Get enrollment challenge
- `POST /api/mobile/biometric/enroll` - Complete enrollment
- `POST /api/mobile/biometric/authenticate/challenge` - Get auth challenge
- `POST /api/mobile/biometric/authenticate` - Authenticate user
- `GET /api/mobile/biometric/enroll/status` - Check enrollment status

### 4. 💳 Mobile Wallet (Apple Pay & Google Pay)

One-tap checkout with Apple Pay and Google Pay integration.

**Features:**
- Apple Pay integration
- Google Pay integration
- Secure tokenized payments
- One-tap checkout
- Saved payment methods
- Transaction history

**Usage:**

```javascript
// HTML
<div data-controller="mobile-wallet"
     data-mobile-wallet-order-id-value="<%= @order.id %>"
     data-mobile-wallet-amount-value="<%= @order.total %>">
  
  <button data-mobile-wallet-target="applePayButton"
          data-action="click->mobile-wallet#startApplePay"
          class="apple-pay-button hidden">
  </button>
  
  <button data-mobile-wallet-target="googlePayButton"
          data-action="click->mobile-wallet#startGooglePay"
          class="google-pay-button hidden">
  </button>
</div>

// Listen for events
document.addEventListener('wallet:payment-success', (event) => {
  console.log('Payment successful:', event.detail)
})
```

**API Endpoints:**
- `POST /api/mobile/apple-pay-payment` - Process Apple Pay payment
- `POST /api/mobile/google-pay-payment` - Process Google Pay payment
- `POST /api/mobile/apple-pay-merchant-validation` - Validate Apple Pay merchant
- `POST /api/mobile/google-pay-config` - Get Google Pay configuration

### 5. 📍 Geolocation Features

Discover nearby stores, local deals, and products available near you.

**Features:**
- Nearby store finder
- Local product listings
- Geofenced alerts and notifications
- Distance-based search
- Location-based recommendations
- Real-time location tracking
- Reverse geocoding

**Usage:**

```javascript
// HTML
<div data-controller="geolocation" data-geolocation-auto-update-value="true">
  <div data-geolocation-target="status"></div>
  <div data-geolocation-target="nearbyStores"></div>
  <div data-geolocation-target="nearbyListings"></div>
  <div data-geolocation-target="localDeals"></div>
  
  <button data-action="click->geolocation#getCurrentLocation">
    Get My Location
  </button>
  <button data-action="click->geolocation#findNearbyStores">
    Find Nearby Stores
  </button>
  <button data-action="click->geolocation#findLocalDeals">
    Find Local Deals
  </button>
</div>

// Listen for events
document.addEventListener('geolocation:updated', (event) => {
  console.log('Location:', event.detail)
})

document.addEventListener('geolocation:alert', (event) => {
  console.log('Geofence alert:', event.detail)
})
```

**API Endpoints:**
- `POST /api/mobile/nearby-stores` - Find nearby stores
- `POST /api/mobile/nearby-listings` - Find nearby product listings
- `POST /api/mobile/local-deals` - Find local deals
- `POST /api/mobile/location-recommendations` - Get location-based recommendations
- `POST /api/mobile/geofence-alerts` - Check for geofence alerts

### 6. 📴 Offline Mode

Browse products and queue actions even without internet connection.

**Features:**
- Offline product browsing
- Cart management offline
- Wishlist access offline
- Action queuing for sync
- Automatic sync when online
- IndexedDB storage
- Service Worker caching
- Background sync

**Usage:**

```javascript
// HTML
<div data-controller="offline-mode">
  <div data-offline-mode-target="status"></div>
  <div data-offline-mode-target="offlineIndicator" class="hidden">
    📴 Offline Mode
  </div>
  
  <button data-offline-mode-target="syncButton"
          data-action="click->offline-mode#syncPendingActions">
    Sync Changes
  </button>
</div>

// Queue actions for later sync
const controller = this.application.getControllerForElementAndIdentifier(
  element, 'offline-mode'
)

controller.queueAction({
  type: 'add_to_cart',
  data: { product_id: 123, quantity: 1 }
})

// Listen for events
document.addEventListener('offline:synced', (event) => {
  console.log('Synced:', event.detail)
})
```

**API Endpoints:**
- `POST /api/mobile/sync` - Sync offline actions

### 7. 🔔 Push Notifications

Personalized alerts for abandoned carts, price drops, and order updates.

**Features:**
- Web Push notifications
- Personalized alerts
- Abandoned cart reminders
- Price drop notifications
- Order status updates
- Geofence-triggered notifications
- Rich notifications with actions

**Usage:**

```javascript
// Already integrated via push_notifications_controller.js
// Automatically requests permission and subscribes

// Send test notification
fetch('/api/mobile/test-notification', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken
  }
})
```

**API Endpoints:**
- `POST /api/mobile/push-subscription` - Register push subscription
- `POST /api/mobile/test-notification` - Send test notification

## Setup Instructions

### 1. Run Database Migration

```bash
rails db:migrate
```

### 2. Configure Credentials

```bash
rails credentials:edit
```

Add the following:

```yaml
# Barcode lookup API
barcode_lookup:
  api_key: your_barcode_lookup_api_key

# Google Vision API for visual search
google_vision:
  api_key: your_google_vision_api_key

# Apple Pay
apple_pay:
  merchant_id: your_apple_merchant_id
  domain: yourdomain.com
  certificate_path: path/to/apple_pay_cert.pem

# Google Pay
google_pay:
  merchant_id: your_google_merchant_id
  merchant_name: TheFinalMarket

# Push notifications (already configured)
vapid_public_key: your_vapid_public_key
vapid_private_key: your_vapid_private_key
```

### 3. Update User Model

Add associations to `app/models/user.rb`:

```ruby
has_many :barcode_scans, dependent: :destroy
has_many :push_subscriptions, dependent: :destroy
has_many :mobile_devices, dependent: :destroy
```

### 4. Enable HTTPS

Mobile features require HTTPS. In development, use:

```bash
rails s -b 'ssl://localhost:3000?key=localhost.key&cert=localhost.crt'
```

Or use a service like ngrok:

```bash
ngrok http 3000
```

## Browser Support

### Required Features:
- **Camera Access**: `navigator.mediaDevices.getUserMedia()`
- **Geolocation**: `navigator.geolocation`
- **Service Workers**: For offline mode and push notifications
- **IndexedDB**: For offline data storage
- **WebAuthn**: For biometric authentication
- **Payment Request API**: For Apple Pay/Google Pay

### Supported Browsers:
- ✅ Chrome/Edge 90+
- ✅ Safari 14+ (iOS 14+)
- ✅ Firefox 88+
- ✅ Samsung Internet 14+

## Security Considerations

1. **HTTPS Required**: All mobile features require HTTPS
2. **Permissions**: Request camera, location, and notification permissions responsibly
3. **Biometric Data**: Never stored on server, only credential IDs
4. **Payment Tokens**: Tokenized, never store raw card data
5. **Location Privacy**: Allow users to opt-out of location tracking
6. **Offline Data**: Encrypt sensitive data in IndexedDB

## Performance Optimization

1. **Lazy Loading**: Load camera/AR features only when needed
2. **Image Compression**: Compress images before visual search
3. **Caching**: Aggressive caching for offline mode
4. **Background Sync**: Use Service Worker background sync
5. **Debouncing**: Debounce geolocation updates

## Testing

### Test Barcode Scanner:
1. Open `/mobile/scanner` on mobile device
2. Point camera at barcode
3. Verify product lookup and price comparison

### Test Visual Search:
1. Open `/mobile/camera` on mobile device
2. Take photo of product
3. Verify similar products are found

### Test Biometric Auth:
1. Open `/mobile/biometric` on supported device
2. Enroll biometric credential
3. Test authentication

### Test Mobile Wallet:
1. Add items to cart
2. Proceed to checkout
3. Select Apple Pay or Google Pay
4. Complete payment

### Test Geolocation:
1. Allow location permission
2. View nearby stores and deals
3. Verify distance calculations

### Test Offline Mode:
1. Load app while online
2. Disconnect from internet
3. Browse products, add to cart
4. Reconnect and verify sync

## Troubleshooting

### Camera not working:
- Ensure HTTPS is enabled
- Check browser permissions
- Verify camera is not in use by another app

### Biometric auth failing:
- Ensure device has biometric hardware
- Check browser support for WebAuthn
- Verify HTTPS connection

### Geolocation not accurate:
- Enable high accuracy mode
- Check device GPS settings
- Verify location permissions

### Offline sync not working:
- Check Service Worker registration
- Verify IndexedDB is enabled
- Check browser console for errors

## Next Steps

1. **Customize UI**: Style mobile components to match your brand
2. **Add Analytics**: Track mobile feature usage
3. **A/B Testing**: Test different mobile experiences
4. **Push Notification Strategy**: Plan notification campaigns
5. **AR Models**: Create 3D models for AR try-on
6. **Geofence Campaigns**: Set up location-based promotions

## Support

For issues or questions:
- Check browser console for errors
- Review API endpoint responses
- Test on multiple devices
- Contact support with device/browser details

