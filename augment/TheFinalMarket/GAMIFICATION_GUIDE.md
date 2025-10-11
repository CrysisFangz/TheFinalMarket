# Gamification System Guide

## Overview

The Final Market now features a comprehensive gamification system designed to increase user engagement, retention, and satisfaction. This system includes achievements, daily challenges, leaderboards, and a dual-currency reward system.

---

## Features

### 1. Achievement System

**What are Achievements?**
Achievements are special milestones that users can unlock by completing specific actions or reaching certain goals on the platform.

**Achievement Tiers:**
- 🥉 **Bronze**: Entry-level achievements (50-200 points)
- 🥈 **Silver**: Intermediate achievements (200-1000 points)
- 🥇 **Gold**: Advanced achievements (1000-3000 points)
- 💎 **Platinum**: Expert achievements (3000-5000 points)
- 💠 **Diamond**: Legendary achievements (5000+ points)

**Achievement Categories:**
- **Shopping**: Related to purchasing activities
- **Selling**: Related to selling products
- **Social**: Related to community engagement
- **Engagement**: Related to platform usage
- **Milestone**: Major accomplishments
- **Special**: Hidden achievements for discovery

**Achievement Types:**
- **One-Time**: Can only be earned once
- **Progressive**: Track progress toward a goal
- **Repeatable**: Can be earned multiple times
- **Seasonal**: Limited-time achievements
- **Hidden**: Secret achievements for discovery

**Example Achievements:**
- 🛍️ **First Purchase** (Bronze): Make your first purchase - 500 points
- 💰 **Big Spender** (Gold): Spend $1,000 total - 2000 points
- 🏪 **Sales Master** (Gold): Complete 50 sales - 3000 points
- 🔥 **Month Streak** (Gold): Login for 30 consecutive days - 2500 points

---

### 2. Daily Challenges

**What are Daily Challenges?**
Daily challenges are time-limited tasks that refresh every day, providing users with fresh goals and rewards.

**Challenge Difficulties:**
- 🟢 **Easy**: Simple tasks (50-100 points)
- 🟡 **Medium**: Moderate tasks (100-200 points)
- 🔴 **Hard**: Challenging tasks (200-500 points)
- ⚫ **Expert**: Very difficult tasks (500+ points)

**Challenge Types:**
- Browse Products
- Add to Wishlist
- Make Purchase
- Leave Review
- List Product
- Share Product
- Complete Profile
- Invite Friend
- Participate in Discussion
- Watch Live Event

**Example Challenges:**
- "Window Shopper": Browse 10 different products (50 points, 10 coins)
- "Review Master": Leave a detailed review (100 points, 25 coins)
- "Social Butterfly": Share 2 products with friends (60 points, 12 coins)

**Challenge Streaks:**
Complete all daily challenges for consecutive days to build your challenge streak and earn bonus rewards!

---

### 3. Points & Coins System

**Points (Experience Points)**
- Primary currency for progression
- Earned through activities and achievements
- Used to level up
- Cannot be spent (permanent progression)

**How to Earn Points:**
- View products: 5 points
- Make purchases: 10% of purchase amount
- List products: 50 points
- Leave reviews: 50-100 points (more for detailed reviews)
- Complete achievements: 50-5000+ points
- Complete daily challenges: 50-500 points
- Daily login: 25 points
- Referrals: 500 points

**Coins (Premium Currency)**
- Secondary currency for special features
- Earned through achievements and challenges
- Can be spent on premium features
- Can be purchased (future feature)

**How to Earn Coins:**
- Complete achievements: 25-1000 coins
- Complete daily challenges: 10-100 coins
- Level up: 50 coins per level
- Streak milestones: 50 coins per week
- Share products: 5 coins
- Referrals: 100 coins

**How to Spend Coins:**
- Unlock premium themes
- Boost product listings
- Featured placement
- Custom badges
- Special effects
- Priority support

---

### 4. Leveling System

**How Leveling Works:**
Users gain levels by accumulating points. The leveling system uses an exponential curve to ensure progression remains challenging but achievable.

**Level Formula:**
- Level = floor(sqrt(points / 100)) + 1
- Points for Level N = (N - 1)² × 100

**Level Examples:**
- Level 1: 0 points
- Level 2: 100 points
- Level 5: 1,600 points
- Level 10: 8,100 points
- Level 20: 36,100 points
- Level 50: 240,100 points

**Level Rewards:**
- Coins: 50 × level
- Feature unlocks at specific levels:
  - Level 5: Custom Profile Theme
  - Level 10: Priority Support
  - Level 15: Seller Badge
  - Level 20: Custom Storefront
  - Level 25: Advanced Analytics
  - Level 50: VIP Status

---

### 5. Streak System

**Login Streaks:**
- Login daily to build your streak
- Earn bonus points for consecutive days
- Streak milestones award extra coins
- Breaks if you miss a day

**Streak Rewards:**
- Daily login: 25 points
- 7-day streak: 50 coins bonus
- 14-day streak: 100 coins bonus
- 30-day streak: 250 coins bonus

**Challenge Streaks:**
- Complete all daily challenges each day
- Separate from login streaks
- Additional rewards for consistency

---

### 6. Leaderboards

**Leaderboard Types:**
- 🏆 **Points Leaders**: Top users by total points
- 💰 **Top Sellers**: Highest sales volume
- 🛍️ **Top Buyers**: Most purchases made
- ⭐ **Top Reviewers**: Most helpful reviews
- 🔥 **Longest Streaks**: Best login streaks

**Time Periods:**
- Daily
- Weekly
- Monthly
- Yearly
- All-Time

**Leaderboard Rewards:**
- Top 10: Special badge
- Top 3: Featured on homepage
- #1: Exclusive rewards and recognition

---

## User Interface

### Dashboard
Access your gamification dashboard at `/gamification/dashboard`

**Dashboard Sections:**
1. **Stats Overview**: Points, Coins, Level, Streak
2. **Daily Challenges**: Today's challenges with progress
3. **Recent Achievements**: Latest unlocked achievements
4. **Leaderboard Preview**: Your rankings

### Real-Time Updates
The system uses WebSockets (Action Cable) for real-time updates:
- Instant point/coin notifications
- Achievement unlock celebrations
- Level-up animations
- Challenge completion effects

### Animations
- 🎊 Confetti for achievements and level-ups
- ✨ Floating points/coins animations
- 📊 Progress bar animations
- 🎉 Celebration modals

---

## API Integration

### Tracking User Actions

```ruby
# In your controllers or services
gamification_service = GamificationService.new(current_user)

# Track product view
gamification_service.track_action(:product_view, {
  product_name: @product.name
})

# Track purchase
gamification_service.track_action(:product_purchase, {
  amount: @order.total_amount,
  order_id: @order.id
})

# Track review
gamification_service.track_action(:review_created, {
  product_name: @product.name,
  review_length: @review.content.length,
  has_photos: @review.photos.attached?
})
```

### Manual Point/Coin Awards

```ruby
gamification_service = GamificationService.new(user)

# Award points
gamification_service.award_points(100, "Special promotion")

# Award coins
gamification_service.award_coins(50, "Contest winner")
```

### Check Achievements

```ruby
gamification_service = GamificationService.new(user)
gamification_service.check_achievements
```

---

## Database Schema

### Tables Created:
- `achievements`: Achievement definitions
- `user_achievements`: User's earned achievements
- `daily_challenges`: Daily challenge definitions
- `user_daily_challenges`: User's challenge progress
- `leaderboards`: Leaderboard configurations
- `points_transactions`: Points transaction history
- `coins_transactions`: Coins transaction history
- `unlocked_features`: User's unlocked features

### User Model Additions:
- `coins`: Integer (premium currency)
- `current_login_streak`: Integer
- `longest_login_streak`: Integer
- `last_login_date`: Date
- `challenge_streak`: Integer
- `total_achievements`: Integer

---

## Setup Instructions

### 1. Run Migrations

```bash
rails db:migrate
```

### 2. Seed Initial Data

```bash
rails db:seed:gamification
```

Or manually:
```ruby
load Rails.root.join('db/seeds/gamification_seeds.rb')
```

### 3. Generate Daily Challenges

Add to your scheduler (config/schedule.rb):
```ruby
every 1.day, at: '12:00 am' do
  runner "DailyChallenge.generate_for_date(Date.current)"
end
```

### 4. Refresh Leaderboards

Add to your scheduler:
```ruby
every 1.hour do
  runner "Leaderboard.refresh_all"
end
```

---

## Best Practices

### For Developers

1. **Track All User Actions**: Integrate gamification tracking into all relevant user actions
2. **Use Background Jobs**: Process achievement checks asynchronously for better performance
3. **Cache Leaderboards**: Use Redis to cache leaderboard data
4. **Test Thoroughly**: Ensure point calculations are accurate
5. **Monitor Performance**: Track the impact on database and application performance

### For Product Managers

1. **Balance Rewards**: Ensure rewards are meaningful but not too easy to obtain
2. **Regular Updates**: Add new achievements and challenges regularly
3. **Seasonal Events**: Create special limited-time achievements
4. **User Feedback**: Monitor which achievements are popular
5. **A/B Testing**: Test different reward structures

### For Designers

1. **Visual Feedback**: Ensure all actions have clear visual feedback
2. **Celebration Moments**: Make achievement unlocks feel special
3. **Progress Visibility**: Show users their progress clearly
4. **Mobile Optimization**: Ensure animations work well on mobile
5. **Accessibility**: Ensure all features are accessible

---

## Troubleshooting

### Points Not Updating
- Check if GamificationService is being called
- Verify user associations are correct
- Check background job queue

### Achievements Not Unlocking
- Verify achievement requirements
- Check if achievement is active
- Ensure check_achievements is being called

### Leaderboards Not Refreshing
- Check if scheduled job is running
- Verify Leaderboard.refresh_all is executing
- Check for database query performance issues

---

## Future Enhancements

### Planned Features:
- [ ] Team/Guild system
- [ ] Achievement trading/gifting
- [ ] Seasonal events and limited achievements
- [ ] Achievement showcase on profiles
- [ ] Social sharing of achievements
- [ ] Achievement-based matchmaking
- [ ] Coin shop for premium features
- [ ] Achievement difficulty ratings
- [ ] Progress predictions
- [ ] Personalized achievement recommendations

---

## Support

For questions or issues with the gamification system:
- Check the code documentation
- Review the ENHANCEMENTS_ROADMAP.md
- Contact the development team

---

## Credits

Gamification System v1.0
Developed for The Final Market
Built with Ruby on Rails 8.0, Stimulus, and Action Cable

