class CustomerSegmentUpdateJob < ApplicationJob
  queue_as :default
  
  def perform(segment_id = nil)
    if segment_id
      # Update specific segment
      segment = CustomerSegment.find(segment_id)
      update_segment(segment)
    else
      # Update all auto-update segments
      CustomerSegment.auto_segments.active.find_each do |segment|
        update_segment(segment)
      end
    end
  end
  
  private
  
  def update_segment(segment)
    Rails.logger.info "Updating customer segment: #{segment.name}"
    
    begin
      segment.update_members!
      Rails.logger.info "Successfully updated segment #{segment.name} with #{segment.member_count} members"
    rescue => e
      Rails.logger.error "Failed to update segment #{segment.name}: #{e.message}"
      raise e
    end
  end
end

