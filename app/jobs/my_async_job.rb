module MyAsyncJob
  class MyOtherJob < ActiveJob::Base
    queue_as :default

    def perform(transaction_id)
      ActiveRecord::Base.connection_pool.with_connection do
        trx = Transaction.find_by_id(transaction_id)
        Rails.logger.info "[MyAsyncJob::MyOtherJob]"
      end
    end
  end
end
