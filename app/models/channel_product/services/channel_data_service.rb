# frozen_string_literal: true

module ChannelProduct
  module Services
    class ChannelDataService
      MAX_DATA_SIZE = 50_000 # 50KB limit

      def update_data(channel_product, data)
        validate_data(data)

        new_channel_data = merge_channel_data(channel_product, data)
        channel_product.update!(channel_specific_data: new_channel_data)

        publish_update_event(channel_product, data)
        new_channel_data
      end

      private

      def validate_data(data)
        raise ChannelDataError, 'Channel data must be a hash' unless data.is_a?(Hash)

        if data.to_json.bytesize > MAX_DATA_SIZE
          raise ChannelDataError, 'Channel data too large'
        end

        validate_content(data)
      end

      def validate_content(data)
        if data[:title] && data[:title].length > 200
          raise ChannelDataError, 'Title too long'
        end

        if data[:description] && data[:description].length > 5000
          raise ChannelDataError, 'Description too long'
        end

        if data[:images] && data[:images].size > 50
          raise ChannelDataError, 'Too many images'
        end
      end

      def merge_channel_data(channel_product, data)
        existing_data = channel_product.channel_specific_data || {}
        existing_data.deep_merge(data.deep_symbolize_keys)
      end

      def publish_update_event(channel_product, data)
        EventStore::Repository.new.publish(
          ChannelDataUpdated.new(
            channel_product_id: channel_product.id,
            updated_data: data,
            timestamp: Time.current
          )
        )
      rescue => e
        Rails.logger.error("Failed to publish channel data event: #{e.message}")
      end
    end

    class ChannelDataError < StandardError
      def initialize(message = 'Channel data validation failed')
        super(message)
      end
    end

    class ChannelDataUpdated < RailsEventStore::Event
      def self.strict; end
    end
  end
end