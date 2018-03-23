require 'rails_helper'

RSpec.describe TotalPayments::MyFirstJob, type: :job do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:worker) { described_class }
  let(:prev_day) do
    Time.parse('2017-11-07 01:00:00 CST -06:00')
        .in_time_zone('Eastern Time (US & Canada)')
  end
  let(:my_job) { described_class.new }
  let(:test_count) { 14 }

  before :each do
    stub_const('MyModuleJob::MyFirstJob::MIN_STEP', 1)
    stub_total_batch(:paid)

    # since times runs n+1 times
    1.upto(test_count) do
      create_total_batch_base(prev_day)
    end
  end

  it 'distributes the time difference correctly' do
    expect(worker.new.time_difference(test_count)).to eq(worker::SECONDS / test_count)
  end

  it 'queues the job' do
    expect { worker.perform_later }
      .to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it 'is in urgent queue' do
    expect(worker.new.queue_name).to match(/default/)
  end

  describe '00:00 start run' do
    let(:start_day) do
      Time.parse('2017-11-08 00:00:00 CST -06:00')
          .in_time_zone('Eastern Time (US & Canada)')
    end

    before :each do
      travel_to(start_day)
    end

    after(:each) { travel_back }

    it 'first run out of slot' do
      expect(MyAsyncJob::MyOtherJob).not_to receive(:perform_later).with(anything)
      worker.perform_now
    end

    it 'first run out of slot, to first slot' do
      expect(MyAsyncJob::MyOtherJob).to receive(:perform_later).with(anything).twice
      (1..20).each do |run_step|
        worker.perform_now
        # travel_to(start_day + run_step.hour)
      end

      expect do
        1.upto(3) do |run_step|
          worker.new.perform
          travel_to(start_day + run_step.hour)
        end
      end.to have_enqueued_job(MyAsyncJob::MyOtherJob).exactly(3).times
    end
  end

  describe '5 AM start run' do
    let(:start_day) do
      Time.parse("2017-11-08 05:00:00 CST -06:00")
          .in_time_zone('Eastern Time (US & Canada)')
    end

    before :each do
      travel_to(start_day)
    end

    after(:each) { travel_back }

    it '1 run' do
      expect(MyAsyncJob::MyOtherJob).to receive(:perform_later).with(anything).twice
      # 13
      worker.perform_now # 10
    end


    it '2 runs' do
      expect(MyAsyncJob::MyOtherJob).to receive(:perform_later).with(anything).exactly(4).times
      # 13
      worker.perform_now # 10
      travel_to(start_day + 1.hour)
      worker.perform_now # 9
    end

    it '3 runs' do
      expect(MyAsyncJob::MyOtherJob).to receive(:perform_later).with(anything).exactly(6).times
      # 13
      worker.perform_now # 10
      travel_to(start_day + 1.hour)
      worker.perform_now # 9
      travel_to(start_day + 2.hours)
      worker.perform_now # 7
    end

    it '4 runs' do
      expect(MyAsyncJob::MyOtherJob).to receive(:perform_later).with(anything).exactly(7).times
      # 13
      worker.perform_now # 10
      travel_to(start_day + 1.hour)
      worker.perform_now # 9
      travel_to(start_day + 2.hours)
      worker.perform_now # 7
      travel_to(start_day + 3.hours)
      worker.perform_now # 6
    end

    it '9 runs' do
      expect(MyAsyncJob::MyOtherJob).to receive(:perform_later).with(anything).exactly(12).times
      (1..9).each do |run_step|
        worker.perform_now
        travel_to(start_day + run_step.hour)
      end
    end

    it 'last run' do
      expect(MyAsyncJob::MyOtherJob).to receive(:perform_later).with(anything).exactly(13).times
      (1..10).each do |run_step|
        worker.perform_now
        travel_to(start_day + run_step.hour)
      end
    end
  end

  describe '23:00 start run' do
    let(:start_day) { Time.parse("2017-11-08 23:00:00 CST -06:00").in_time_zone('Eastern Time (US & Canada)') }

    before :each do
      travel_to(start_day)
    end

    after(:each) { travel_back }

    it 'last slot run all' do
      expect(MyAsyncJob::MyOtherJob).not_to receive(:perform_later).with(anything).exactly(13).times
      # 13
      worker.perform_now # 0
    end

    it 'last slot run all, next slot nothing' do
      expect(MyAsyncJob::MyOtherJob).not_to receive(:perform_later).with(anything).exactly(13).times
      # 13
      worker.perform_now # 0
      travel_to(start_day + 1.hour)
      worker.perform_now # 0
    end
  end

  context 'Respect min limit' do
    let(:start_day) do
      Time.parse("2017-11-08 19:00:00 CST -06:00")
          .in_time_zone('Eastern Time (US & Canada)')
    end

    before :each do
      travel_to(start_day)
      stub_const("BatchPaymentJob::CfeTotalBatch::MIN_STEP", 10)
    end

    after(:each) { travel_back }

    it '1 run' do
      expect(MyAsyncJob::MyOtherJob).not_to receive(:perform_later).with(anything).exactly(10).times # 13
      worker.perform_now # 3
    end

    it '1 run' do
      expect(MyAsyncJob::MyOtherJob).not_to receive(:perform_later).with(anything).exactly(13).times # 13
      worker.perform_now # 3
      travel_to(start_day + 1.hour)
      worker.perform_now # 0
    end
  end

  def create_total_batch_base(created_at)
    base_trx = transactions(:default).dup
    base_trx.status = 'unpaid'
    base_trx.created_at = created_at
    base_trx.save!
  end

  def stub_total_batch(processor_pay_status)
     allow(MyAsyncJob::MyOtherJob).to receive(:perform_later) do |base_id|
       rec = Transaction.find_by_id(base_id)
       rec.update(status: processor_pay_status)
     end
   end
end
