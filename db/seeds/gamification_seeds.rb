# Gamification Seeds

puts "Creating achievements..."

# Shopping Achievements
Achievement.find_or_create_by!(identifier: 'first_purchase') do |a|
  a.name = 'First Purchase'
  a.description = 'Make your first purchase on The Final Market'
  a.category = :shopping
  a.tier = :bronze
  a.achievement_type = :one_time
  a.points = 500
  a.reward_coins = 100
  a.requirement_type = 'purchase_count'
  a.requirement_value = 1
  a.icon_url = '/icons/achievements/first_purchase.svg'
end

Achievement.find_or_create_by!(identifier: 'shopping_spree') do |a|
  a.name = 'Shopping Spree'
  a.description = 'Make 10 purchases'
  a.category = :shopping
  a.tier = :silver
  a.achievement_type = :progressive
  a.points = 1000
  a.reward_coins = 250
  a.requirement_type = 'purchase_count'
  a.requirement_value = 10
  a.icon_url = '/icons/achievements/shopping_spree.svg'
end

Achievement.find_or_create_by!(identifier: 'big_spender') do |a|
  a.name = 'Big Spender'
  a.description = 'Spend $1,000 total on purchases'
  a.category = :shopping
  a.tier = :gold
  a.achievement_type = :progressive
  a.points = 2000
  a.reward_coins = 500
  a.requirement_type = 'total_spent'
  a.requirement_value = 100000 # in cents
  a.icon_url = '/icons/achievements/big_spender.svg'
end

# Selling Achievements
Achievement.find_or_create_by!(identifier: 'first_sale') do |a|
  a.name = 'First Sale'
  a.description = 'Make your first sale'
  a.category = :selling
  a.tier = :bronze
  a.achievement_type = :one_time
  a.points = 500
  a.reward_coins = 100
  a.requirement_type = 'sales_count'
  a.requirement_value = 1
  a.icon_url = '/icons/achievements/first_sale.svg'
end

Achievement.find_or_create_by!(identifier: 'list_10_products') do |a|
  a.name = 'Product Curator'
  a.description = 'List 10 products for sale'
  a.category = :selling
  a.tier = :silver
  a.achievement_type = :progressive
  a.points = 750
  a.reward_coins = 150
  a.requirement_type = 'product_count'
  a.requirement_value = 10
  a.unlocks = ['custom_storefront']
  a.icon_url = '/icons/achievements/product_curator.svg'
end

Achievement.find_or_create_by!(identifier: 'sales_master') do |a|
  a.name = 'Sales Master'
  a.description = 'Complete 50 sales'
  a.category = :selling
  a.tier = :gold
  a.achievement_type = :progressive
  a.points = 3000
  a.reward_coins = 750
  a.requirement_type = 'sales_count'
  a.requirement_value = 50
  a.unlocks = ['advanced_analytics', 'priority_support']
  a.icon_url = '/icons/achievements/sales_master.svg'
end

# Social Achievements
Achievement.find_or_create_by!(identifier: 'first_review') do |a|
  a.name = 'Critic'
  a.description = 'Leave your first review'
  a.category = :social
  a.tier = :bronze
  a.achievement_type = :one_time
  a.points = 100
  a.reward_coins = 25
  a.requirement_type = 'review_count'
  a.requirement_value = 1
  a.icon_url = '/icons/achievements/critic.svg'
end

Achievement.find_or_create_by!(identifier: 'review_master') do |a|
  a.name = 'Review Master'
  a.description = 'Leave 25 helpful reviews'
  a.category = :social
  a.tier = :silver
  a.achievement_type = :progressive
  a.points = 1500
  a.reward_coins = 300
  a.requirement_type = 'review_count'
  a.requirement_value = 25
  a.icon_url = '/icons/achievements/review_master.svg'
end

# Engagement Achievements
Achievement.find_or_create_by!(identifier: 'week_streak') do |a|
  a.name = 'Dedicated'
  a.description = 'Login for 7 consecutive days'
  a.category = :engagement
  a.tier = :bronze
  a.achievement_type = :repeatable
  a.points = 500
  a.reward_coins = 100
  a.requirement_type = 'login_streak'
  a.requirement_value = 7
  a.icon_url = '/icons/achievements/week_streak.svg'
end

Achievement.find_or_create_by!(identifier: 'month_streak') do |a|
  a.name = 'Committed'
  a.description = 'Login for 30 consecutive days'
  a.category = :engagement
  a.tier = :gold
  a.achievement_type = :repeatable
  a.points = 2500
  a.reward_coins = 500
  a.requirement_type = 'login_streak'
  a.requirement_value = 30
  a.icon_url = '/icons/achievements/month_streak.svg'
end

Achievement.find_or_create_by!(identifier: 'profile_complete') do |a|
  a.name = 'All Set'
  a.description = 'Complete your profile 100%'
  a.category = :milestone
  a.tier = :bronze
  a.achievement_type = :one_time
  a.points = 200
  a.reward_coins = 50
  a.icon_url = '/icons/achievements/profile_complete.svg'
end

# Special/Hidden Achievements
Achievement.find_or_create_by!(identifier: 'early_bird') do |a|
  a.name = 'Early Bird'
  a.description = 'Make a purchase before 6 AM'
  a.category = :special
  a.tier = :silver
  a.achievement_type = :one_time
  a.points = 300
  a.reward_coins = 75
  a.hidden = true
  a.icon_url = '/icons/achievements/early_bird.svg'
end

Achievement.find_or_create_by!(identifier: 'night_owl') do |a|
  a.name = 'Night Owl'
  a.description = 'Make a purchase after midnight'
  a.category = :special
  a.tier = :silver
  a.achievement_type = :one_time
  a.points = 300
  a.reward_coins = 75
  a.hidden = true
  a.icon_url = '/icons/achievements/night_owl.svg'
end

Achievement.find_or_create_by!(identifier: 'lucky_number') do |a|
  a.name = 'Lucky Number Seven'
  a.description = 'Make your 7th purchase'
  a.category = :special
  a.tier = :bronze
  a.achievement_type = :one_time
  a.points = 777
  a.reward_coins = 77
  a.hidden = true
  a.icon_url = '/icons/achievements/lucky_seven.svg'
end

puts "Created #{Achievement.count} achievements"

# Create Leaderboards
puts "Creating leaderboards..."

Leaderboard.find_or_create_by!(
  leaderboard_type: :points,
  period: :all_time
) do |l|
  l.name = 'All-Time Points Leaders'
  l.description = 'Top users by total points earned'
  l.active = true
end

Leaderboard.find_or_create_by!(
  leaderboard_type: :sales,
  period: :monthly
) do |l|
  l.name = 'Monthly Top Sellers'
  l.description = 'Top sellers by monthly sales volume'
  l.active = true
end

Leaderboard.find_or_create_by!(
  leaderboard_type: :purchases,
  period: :weekly
) do |l|
  l.name = 'Weekly Top Buyers'
  l.description = 'Most active buyers this week'
  l.active = true
end

Leaderboard.find_or_create_by!(
  leaderboard_type: :reviews,
  period: :all_time
) do |l|
  l.name = 'Top Reviewers'
  l.description = 'Users with the most helpful reviews'
  l.active = true
end

Leaderboard.find_or_create_by!(
  leaderboard_type: :streak,
  period: :all_time
) do |l|
  l.name = 'Longest Streaks'
  l.description = 'Users with the longest login streaks'
  l.active = true
end

puts "Created #{Leaderboard.count} leaderboards"

# Generate today's daily challenges
puts "Generating daily challenges..."
DailyChallenge.generate_for_date(Date.current)
puts "Created #{DailyChallenge.today.count} daily challenges for today"

puts "Gamification seeds completed!"

