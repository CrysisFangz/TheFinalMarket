class CustomerSegmentPresenter
  attr_reader :segment

  def initialize(segment)
    @segment = segment
  end

  def as_json(options = {})
    {
      id: segment.id,
      name: segment.name,
      segment_type: segment.segment_type,
      active: segment.active,
      auto_update: segment.auto_update,
      member_count: segment.member_count,
      last_updated_at: segment.last_updated_at,
      criteria: segment.criteria
    }.merge(options)
  end

  def for_api
    as_json
  end
end