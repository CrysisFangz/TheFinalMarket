puts "🎮 Seeding Enhanced Gamification System..."

# Get some users and products for testing
users = User.limit(20).to_a
products = Product.limit(50).to_a
categories = Category.limit(10).to_a

# ===== TREASURE HUNTS =====
puts "  Creating Treasure Hunts..."

treasure_hunt_1 = TreasureHunt.create!(
  name: "Summer Treasure Hunt",
  description: "Find hidden treasures across our marketplace!",
  status: :active,
  difficulty: :medium,
  starts_at: 1.day.ago,
  ends_at: 30.days.from_now,
  max_participants: 100,
  prize_pool: 10000
)

# Create clues for treasure hunt
5.times do |i|
  TreasureHuntClue.create!(
    treasure_hunt: treasure_hunt_1,
    product: products.sample,
    clue_order: i,
    clue_type: [:product_based, :riddle, :category_based].sample,
    clue_text: "Clue #{i + 1}: Find the hidden treasure...",
    hint_text: "Hint 1: Look in electronics||Hint 2: It's portable||Hint 3: Used for communication",
    correct_answer: "smartphone"
  )
end

# Create participations
10.times do
  user = users.sample
  next if treasure_hunt_1.participants.include?(user)
  
  participation = treasure_hunt_1.join(user)
  if participation
    # Simulate some progress
    rand(0..3).times do
      participation.submit_answer("test_answer_#{rand(1000)}")
    end
  end
end

treasure_hunt_2 = TreasureHunt.create!(
  name: "Holiday Mystery Hunt",
  description: "Solve festive riddles to win big prizes!",
  status: :active,
  difficulty: :hard,
  starts_at: Time.current,
  ends_at: 60.days.from_now,
  max_participants: 50,
  prize_pool: 25000
)

# ===== SPIN TO WIN =====
puts "  Creating Spin to Win Wheels..."

spin_wheel = SpinToWin.create!(
  name: "Daily Lucky Spin",
  description: "Spin once per day for amazing prizes!",
  status: :active,
  spins_per_user_per_day: 1,
  requires_purchase: false
)

# Create prizes with different probabilities
SpinToWinPrize.create!([
  {
    spin_to_win: spin_wheel,
    prize_name: "10 Coins",
    prize_type: :coins,
    prize_value: 10,
    probability: 40.0,
    active: true
  },
  {
    spin_to_win: spin_wheel,
    prize_name: "50 Coins",
    prize_type: :coins,
    prize_value: 50,
    probability: 25.0,
    active: true
  },
  {
    spin_to_win: spin_wheel,
    prize_name: "100 Coins",
    prize_type: :coins,
    prize_value: 100,
    probability: 15.0,
    active: true
  },
  {
    spin_to_win: spin_wheel,
    prize_name: "10% Discount",
    prize_type: :discount_code,
    prize_value: 10,
    probability: 10.0,
    active: true
  },
  {
    spin_to_win: spin_wheel,
    prize_name: "Free Shipping",
    prize_type: :free_shipping,
    prize_value: 1,
    probability: 7.0,
    active: true
  },
  {
    spin_to_win: spin_wheel,
    prize_name: "500 Coins JACKPOT!",
    prize_type: :coins,
    prize_value: 500,
    probability: 3.0,
    active: true
  }
])

# Simulate some spins
15.times do
  user = users.sample
  spin_wheel.spin!(user) if spin_wheel.can_spin?(user)
end

# ===== SHOPPING QUESTS =====
puts "  Creating Shopping Quests..."

daily_quest = ShoppingQuest.create!(
  name: "Daily Shopper",
  description: "Complete your daily shopping tasks!",
  quest_type: :daily,
  status: :active,
  difficulty: :beginner,
  starts_at: Time.current.beginning_of_day,
  ends_at: Time.current.end_of_day,
  reward_coins: 100,
  reward_experience: 50,
  reward_tokens: 10
)

QuestObjective.create!([
  {
    shopping_quest: daily_quest,
    objective_type: :purchase_count,
    description: "Make 1 purchase",
    target_value: 1,
    objective_order: 1
  },
  {
    shopping_quest: daily_quest,
    objective_type: :review_product,
    description: "Write a review",
    target_value: 1,
    objective_order: 2
  }
])

weekly_quest = ShoppingQuest.create!(
  name: "Weekly Explorer",
  description: "Explore different categories this week!",
  quest_type: :weekly,
  status: :active,
  difficulty: :intermediate,
  starts_at: Time.current.beginning_of_week,
  ends_at: Time.current.end_of_week,
  reward_coins: 500,
  reward_experience: 250,
  reward_tokens: 50
)

QuestObjective.create!([
  {
    shopping_quest: weekly_quest,
    objective_type: :purchase_count,
    description: "Make 5 purchases",
    target_value: 5,
    objective_order: 1
  },
  {
    shopping_quest: weekly_quest,
    objective_type: :spend_amount,
    description: "Spend $100",
    target_value: 100,
    objective_order: 2
  }
])

# Create quest participations
8.times do
  user = users.sample
  next if daily_quest.participants.include?(user)
  
  daily_quest.start_for(user)
end

# ===== SEASONAL EVENTS =====
puts "  Creating Seasonal Events..."

summer_event = SeasonalEvent.create!(
  name: "Summer Sale Spectacular",
  description: "Join our biggest summer event with amazing challenges and prizes!",
  event_type: :seasonal,
  status: :active,
  starts_at: 1.week.ago,
  ends_at: 3.weeks.from_now,
  theme: "summer",
  banner_url: "/images/summer_banner.jpg"
)

# Create event challenges
EventChallenge.create!([
  {
    seasonal_event: summer_event,
    name: "Summer Shopper",
    description: "Make 3 purchases during the event",
    challenge_type: :purchase,
    points_reward: 100,
    bonus_coins: 50,
    active: true,
    repeatable: false
  },
  {
    seasonal_event: summer_event,
    name: "Social Butterfly",
    description: "Share 5 products on social media",
    challenge_type: :social,
    points_reward: 75,
    bonus_coins: 25,
    active: true,
    repeatable: false
  },
  {
    seasonal_event: summer_event,
    name: "Engaged Shopper",
    description: "Write 3 reviews",
    challenge_type: :engagement,
    points_reward: 150,
    bonus_coins: 75,
    active: true,
    repeatable: false
  }
])

# Create event rewards
EventReward.create!([
  {
    seasonal_event: summer_event,
    reward_type: :milestone,
    reward_name: "100 Points Milestone",
    description: "Reach 100 points",
    threshold: 100,
    prize_type: "coins",
    prize_value: 200
  },
  {
    seasonal_event: summer_event,
    reward_type: :milestone,
    reward_name: "500 Points Milestone",
    description: "Reach 500 points",
    threshold: 500,
    prize_type: "coins",
    prize_value: 1000
  },
  {
    seasonal_event: summer_event,
    reward_type: :leaderboard,
    reward_name: "1st Place Prize",
    description: "Finish in 1st place",
    rank: 1,
    prize_type: "coins",
    prize_value: 5000
  },
  {
    seasonal_event: summer_event,
    reward_type: :leaderboard,
    reward_name: "2nd Place Prize",
    description: "Finish in 2nd place",
    rank: 2,
    prize_type: "coins",
    prize_value: 3000
  },
  {
    seasonal_event: summer_event,
    reward_type: :leaderboard,
    reward_name: "3rd Place Prize",
    description: "Finish in 3rd place",
    rank: 3,
    prize_type: "coins",
    prize_value: 1500
  }
])

# Create event participations
12.times do
  user = users.sample
  next if summer_event.participants.include?(user)

  participation = summer_event.join(user)
  if participation
    # Award some random points
    summer_event.award_points(user, rand(50..300))
  end
end

# ===== SOCIAL COMPETITIONS =====
puts "  Creating Social Competitions..."

individual_comp = SocialCompetition.create!(
  name: "Top Shopper Challenge",
  description: "Compete to be the top shopper this month!",
  competition_type: :individual,
  status: :active,
  scoring_type: :purchases,
  registration_ends_at: 1.week.from_now,
  starts_at: Time.current,
  ends_at: 30.days.from_now,
  max_participants: 100,
  prize_pool: 15000,
  prize_positions: 5
)

# Register participants
10.times do
  user = users.sample
  next if individual_comp.participants.include?(user)

  participant = individual_comp.register(user)
  if participant
    # Simulate some activity
    individual_comp.update_score(user, rand(10..100))
  end
end

team_comp = SocialCompetition.create!(
  name: "Team Shopping Wars",
  description: "Form teams and compete for glory!",
  competition_type: :team,
  status: :registration,
  scoring_type: :points,
  registration_ends_at: 3.days.from_now,
  starts_at: 4.days.from_now,
  ends_at: 34.days.from_now,
  max_participants: 40,
  prize_pool: 20000,
  prize_positions: 3
)

# Create some teams
3.times do |i|
  captain = users.sample
  team = CompetitionTeam.create!(
    social_competition: team_comp,
    captain: captain,
    name: "Team #{['Alpha', 'Beta', 'Gamma'][i]}",
    description: "The best team in the competition!",
    max_members: 5,
    team_color: ['#FF0000', '#00FF00', '#0000FF'][i]
  )

  # Add team members
  team.add_member(captain)
  3.times do
    member = users.sample
    team.add_member(member) unless team.members.include?(member)
  end
end

puts "✅ Enhanced Gamification System seeded successfully!"
puts "  - #{TreasureHunt.count} Treasure Hunts"
puts "  - #{TreasureHuntClue.count} Treasure Hunt Clues"
puts "  - #{TreasureHuntParticipation.count} Hunt Participations"
puts "  - #{SpinToWin.count} Spin to Win Wheels"
puts "  - #{SpinToWinPrize.count} Spin Prizes"
puts "  - #{SpinToWinSpin.count} Spins"
puts "  - #{ShoppingQuest.count} Shopping Quests"
puts "  - #{QuestObjective.count} Quest Objectives"
puts "  - #{SeasonalEvent.count} Seasonal Events"
puts "  - #{EventChallenge.count} Event Challenges"
puts "  - #{SocialCompetition.count} Social Competitions"
puts "  - #{CompetitionTeam.count} Competition Teams"

