# app/queries/recent_orders_query.rb
class RecentOrdersQuery
  def self.call(limit: 10)
    StoreOrder.recent.limit(limit)
  end
end