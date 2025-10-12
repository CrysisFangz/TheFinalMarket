# 🎮 The Final Market - Enhanced Gamification Guide

## Overview

The Final Market features a comprehensive gamification system with treasure hunts, spin-to-win wheels, shopping quests, seasonal events, and social competitions to create an engaging and rewarding shopping experience.

---

## 🎯 Features

### 1. Treasure Hunts

#### Overview
Interactive scavenger hunts where users solve clues to find hidden treasures across the marketplace.

#### Features
- **4 Difficulty Levels:** Easy, Medium, Hard, Expert
- **6 Clue Types:** Product-based, Category-based, Location-based, Riddle, Image-based, QR Code
- **Hint System:** Progressive hints (difficulty-based limits)
- **Leaderboard:** Ranked by completion time
- **Prize Pool:** Distributed to top 3 finishers (50%, 30%, 20%)

#### Usage
```ruby
# Create treasure hunt
hunt = TreasureHunt.create!(
  name: "Summer Treasure Hunt",
  difficulty: :medium,
  starts_at: Time.current,
  ends_at: 30.days.from_now,
  prize_pool: 10000
)

# Add clues
TreasureHuntClue.create!(
  treasure_hunt: hunt,
  clue_order: 0,
  clue_type: :riddle,
  clue_text: "I have keys but no locks...",
  correct_answer: "keyboard",
  hint_text: "Hint 1: Used with computers||Hint 2: Has letters||Hint 3: Input device"
)

# User joins hunt
participation = hunt.join(user)

# Submit answer
result = participation.submit_answer("keyboard")
# => { success: true, completed: false, message: "Correct! Moving to next clue." }

# Use hint
hint = participation.use_hint(1)

# Get leaderboard
leaderboard = hunt.leaderboard(limit: 10)
```

---

### 2. Spin to Win

#### Overview
Daily prize wheel where users can spin for rewards like coins, discounts, free shipping, and more.

#### Features
- **7 Prize Types:** Coins, Discount Code, Free Shipping, Product, Experience Points, Loyalty Tokens, Mystery Box
- **Probability-Based:** Each prize has configurable probability
- **Daily Limits:** Configurable spins per user per day
- **Purchase Requirement:** Optional requirement to make purchase before spinning

#### Usage
```ruby
# Create spin wheel
wheel = SpinToWin.create!(
  name: "Daily Lucky Spin",
  spins_per_user_per_day: 1,
  requires_purchase: false
)

# Add prizes
SpinToWinPrize.create!(
  spin_to_win: wheel,
  prize_name: "100 Coins",
  prize_type: :coins,
  prize_value: 100,
  probability: 15.0  # 15% chance
)

# Check if user can spin
can_spin = wheel.can_spin?(user)  # => true/false

# Spin the wheel
result = wheel.spin!(user)
# => {
#   success: true,
#   prize: <SpinToWinPrize>,
#   remaining_spins: 0,
#   message: "You won: 100 Coins!"
# }

# Get spin history
history = wheel.user_spin_history(user, limit: 10)

# Get statistics
stats = wheel.statistics
# => {
#   total_spins: 1500,
#   unique_spinners: 450,
#   most_common_prize: "10 Coins",
#   total_value_awarded: 25000
# }
```

---

### 3. Shopping Quests

#### Overview
Multi-objective missions that reward users for completing specific shopping tasks.

#### Features
- **6 Quest Types:** Daily, Weekly, Monthly, Seasonal, Special Event, Story Quest
- **4 Difficulty Levels:** Beginner, Intermediate, Advanced, Expert
- **10 Objective Types:** Purchase product, Purchase from category, Spend amount, Purchase count, Review product, Share product, Refer friend, Visit store, Add to wishlist, Complete profile
- **Multiple Rewards:** Coins, Experience Points, Loyalty Tokens, Items, Achievement Unlocks

#### Usage
```ruby
# Create quest
quest = ShoppingQuest.create!(
  name: "Daily Shopper",
  quest_type: :daily,
  difficulty: :beginner,
  starts_at: Time.current.beginning_of_day,
  ends_at: Time.current.end_of_day,
  reward_coins: 100,
  reward_experience: 50
)

# Add objectives
QuestObjective.create!(
  shopping_quest: quest,
  objective_type: :purchase_count,
  description: "Make 3 purchases",
  target_value: 3
)

# User starts quest
participation = quest.start_for(user)

# Check progress
progress = quest.check_progress(user)
# => {
#   progress: 66.67,
#   completed_objectives: 2,
#   total_objectives: 3,
#   completed: false
# }

# Get objectives progress
objectives = participation.objectives_progress
# => [
#   {
#     objective: <QuestObjective>,
#     description: "Make 3 purchases",
#     current: 2,
#     target: 3,
#     progress: 66.67,
#     completed: false
#   }
# ]

# Quest auto-completes when all objectives done
# Rewards are automatically awarded
```

---

### 4. Seasonal Events

#### Overview
Time-limited events with challenges, leaderboards, and exclusive rewards.

#### Features
- **6 Event Types:** Holiday, Seasonal, Anniversary, Flash Sale, Community, Special
- **Challenge System:** Multiple challenges per event
- **5 Challenge Types:** Purchase, Social, Engagement, Collection, Time-Limited
- **Point-Based Leaderboard:** Ranked by points earned
- **4 Reward Types:** Milestone, Leaderboard, Participation, Random Drop

#### Usage
```ruby
# Create seasonal event
event = SeasonalEvent.create!(
  name: "Summer Sale Spectacular",
  event_type: :seasonal,
  starts_at: Time.current,
  ends_at: 30.days.from_now,
  theme: "summer"
)

# Add challenges
EventChallenge.create!(
  seasonal_event: event,
  name: "Summer Shopper",
  challenge_type: :purchase,
  points_reward: 100,
  bonus_coins: 50
)

# Add rewards
EventReward.create!(
  seasonal_event: event,
  reward_type: :milestone,
  reward_name: "100 Points Milestone",
  threshold: 100,
  prize_type: "coins",
  prize_value: 200
)

# User joins event
participation = event.join(user)

# Award points
event.award_points(user, 100, "Completed challenge")

# Complete challenge
challenge.complete_for(user)

# Get leaderboard
leaderboard = event.leaderboard(limit: 100)
# => [
#   { rank: 1, user: <User>, points: 500, joined_at: ... },
#   { rank: 2, user: <User>, points: 450, joined_at: ... },
#   ...
# ]

# Get user's rank
rank = event.user_rank(user)  # => 15

# Get statistics
stats = event.statistics
# => {
#   total_participants: 250,
#   total_points_awarded: 50000,
#   average_points: 200,
#   top_score: 1500,
#   challenges_completed: 750,
#   days_remaining: 15
# }
```

---

### 5. Social Competitions

#### Overview
Competitive events where users compete individually or in teams for prizes.

#### Features
- **4 Competition Types:** Individual, Team, Guild, Bracket
- **6 Scoring Types:** Points, Purchases, Sales, Reviews, Referrals, Engagement
- **Team System:** Create and join teams
- **Registration Period:** Time-limited registration
- **Prize Distribution:** Configurable prize pool and positions

#### Usage
```ruby
# Create individual competition
comp = SocialCompetition.create!(
  name: "Top Shopper Challenge",
  competition_type: :individual,
  scoring_type: :purchases,
  registration_ends_at: 3.days.from_now,
  starts_at: 4.days.from_now,
  ends_at: 34.days.from_now,
  prize_pool: 15000,
  prize_positions: 5
)

# Register user
participant = comp.register(user)

# Update score
comp.update_score(user, 10)

# Get leaderboard
leaderboard = comp.leaderboard(limit: 100)
# => [
#   { rank: 1, user: <User>, score: 150, prize: 7500 },
#   { rank: 2, user: <User>, score: 120, prize: 4500 },
#   ...
# ]

# Create team competition
team_comp = SocialCompetition.create!(
  name: "Team Shopping Wars",
  competition_type: :team,
  ...
)

# Create team
team = CompetitionTeam.create!(
  social_competition: team_comp,
  captain: user,
  name: "Team Alpha",
  max_members: 5
)

# Add members
team.add_member(another_user)

# Get team stats
stats = team.team_stats
# => {
#   name: "Team Alpha",
#   captain: "john_doe",
#   members_count: 4,
#   total_score: 450,
#   average_score: 112.5,
#   rank: 2
# }

# Start competition
comp.start!

# End competition (auto-awards prizes)
comp.finish!
```

---

## 📊 Database Schema

### Treasure Hunts
- `treasure_hunts` - Hunt definitions
- `treasure_hunt_clues` - Clues for each hunt
- `treasure_hunt_participations` - User participation tracking
- `clue_attempts` - Answer attempt history

### Spin to Win
- `spin_to_wins` - Wheel configurations
- `spin_to_win_prizes` - Available prizes
- `spin_to_win_spins` - Spin history

### Shopping Quests
- `shopping_quests` - Quest definitions
- `quest_objectives` - Quest objectives
- `quest_participations` - User quest progress

### Seasonal Events
- `seasonal_events` - Event definitions
- `event_challenges` - Event challenges
- `challenge_completions` - Challenge completion tracking
- `event_participations` - User event participation
- `event_rewards` - Event rewards
- `claimed_event_rewards` - Claimed rewards tracking

### Social Competitions
- `social_competitions` - Competition definitions
- `competition_participants` - Participant tracking
- `competition_teams` - Team definitions

---

## 🎯 Best Practices

### Treasure Hunts
1. Create engaging, themed clues
2. Balance difficulty appropriately
3. Provide helpful hints
4. Set reasonable prize pools
5. Monitor completion rates

### Spin to Win
1. Balance prize probabilities
2. Ensure total probability = 100%
3. Offer variety of prizes
4. Set appropriate daily limits
5. Track prize value distribution

### Shopping Quests
1. Create achievable objectives
2. Balance rewards with difficulty
3. Offer variety of quest types
4. Refresh daily/weekly quests
5. Track completion rates

### Seasonal Events
1. Theme events appropriately
2. Create diverse challenges
3. Set milestone rewards
4. Promote events effectively
5. Monitor engagement

### Social Competitions
1. Set clear rules
2. Balance team sizes
3. Provide fair scoring
4. Communicate updates
5. Award prizes promptly

---

**The Final Market - Gamified Shopping Experience** 🎮

