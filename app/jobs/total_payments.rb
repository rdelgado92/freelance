module TotalPayments
  class MyFirstJob < ActiveJob::Base
    queue_as :default

    MIN_STEP = 50
    INTERVAL = 11
    SECONDS = 300 # 4 minutes

    STEPS = {
      '05:00' => 0, '06:00' => 1, '07:00' => 2, '08:00' => 3, '09:00' => 4,
      '10:00' => 5, '11:00' => 6, '12:00' => 7, '13:00' => 8, '14:00' => 9,
      '15:00' => 10, '16:00' => 11, '17:00' => 12, '18:00' => 13,
      '19:00' => 14, '20:00' => 15, '21:00' => 16, '22:00' => 17,
      '23:00' => 18
    }.freeze

    def perform
      base_records = Transaction.all
      schedule_records(base_records)
    end

    def time_difference(total)
      SECONDS / total
    end

    private

    def schedule_records(base_records)
      base_ids = schedule_base(base_records)
      set_time = 0

      base_ids.in_groups(INTERVAL, false) do |base_id|
        total = base_id.size
        time = total.zero? ? 0 : time_difference(total)

        base_id.each do |base_id_ea|
          MyAsyncJob::MyOtherJob.set(wait: set_time).perform_later(base_id_ea)
          set_time += time
        end
      end
    end

    def step_bases(base_records)
      key = Time.current.in_time_zone('Eastern Time (US & Canada)')
                .beginning_of_hour.strftime('%H:%M')

      current_step = STEPS[key]
      return 0 if current_step.blank?

      pending =
        if current_step < 10
          10.0 - current_step
        else
          19.0 - current_step
        end

      limit = (base_records / pending).ceil
      [limit, MIN_STEP].max
    end

    def schedule_base(base_records)
      step_limit = step_bases(base_records.count)
      base_records.limit(step_limit).pluck(:id)
    end

  end
end
