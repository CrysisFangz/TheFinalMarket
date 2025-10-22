require 'test_helper'

module Application
  module UserCurrencyPreference
    module Commands
      class UpdateUserCurrencyPreferenceCommandTest < ActiveSupport::TestCase
        def setup
          @user = users(:one)
          @currency = currencies(:one)
          @repository = Infrastructure::UserCurrencyPreference::Repositories::UserCurrencyPreferenceRepository.new
        end

        test "should update currency preference successfully" do
          command = UpdateUserCurrencyPreferenceCommand.new(@user.id, @currency.id)
          result = command.execute(@repository)

          assert result.successful?
          assert_equal @currency.id, result.value.currency_id
        end

        test "should fail with invalid user ID" do
          command = UpdateUserCurrencyPreferenceCommand.new(nil, @currency.id)
          assert_raises(ArgumentError) { command.execute(@repository) }
        end

        test "should fail with invalid currency ID" do
          command = UpdateUserCurrencyPreferenceCommand.new(@user.id, nil)
          assert_raises(ArgumentError) { command.execute(@repository) }
        end
      end
    end
  end
end