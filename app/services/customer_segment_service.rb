class CustomerSegmentService
  def update_members(segment)
    case segment.segment_type.to_sym
    when :rfm
      update_rfm_segment(segment)
    when :value_based
      update_value_segment(segment)
    when :engagement
      update_engagement_segment(segment)
    when :behavioral
      update_behavioral_segment(segment)
    when :custom
      update_custom_segment(segment)
    end

    segment.update!(last_updated_at: Time.current, member_count: segment.users.count)
  end

  private

  def update_rfm_segment(segment)
    criteria = segment.criteria || {}

    user_ids = User.joins(:orders)
                   .where(orders: { status: 'completed' })
                   .group('users.id')
                   .having('MAX(orders.created_at) > ?', (criteria['recency_days'] || 30).days.ago)
                   .having('COUNT(orders.id) >= ?', criteria['min_frequency'] || 1)
                   .having('SUM(orders.total_cents) >= ?', criteria['min_monetary'] || 0)
                   .pluck('users.id')

    sync_members(segment, user_ids)
  end

  def update_value_segment(segment)
    criteria = segment.criteria || {}

    user_ids = User.joins(:orders)
                   .where(orders: { status: 'completed' })
                   .group('users.id')
                   .having('SUM(orders.total_cents) >= ?', criteria['min_value'] || 0)
                   .pluck('users.id')

    sync_members(segment, user_ids)
  end

  def update_engagement_segment(segment)
    criteria = segment.criteria || {}

    user_ids = User.where('sign_in_count >= ?', criteria['min_logins'] || 1)
                   .where('last_sign_in_at > ?', (criteria['active_days'] || 30).days.ago)
                   .pluck(:id)

    sync_members(segment, user_ids)
  end

  def update_behavioral_segment(segment)
    # Placeholder for behavioral logic
    sync_members(segment, [])
  end

  def update_custom_segment(segment)
    criteria = segment.criteria || {}

    if criteria['sql_query'].present?
      user_ids = User.connection.select_values(criteria['sql_query'])
      sync_members(segment, user_ids)
    end
  end

  def sync_members(segment, user_ids)
    segment.customer_segment_members.where.not(user_id: user_ids).destroy_all

    user_ids.each do |user_id|
      segment.customer_segment_members.find_or_create_by!(user_id: user_id)
    end
  end
end