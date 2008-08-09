#!/usr/bin/env ruby

require File.dirname(__FILE__) + "/../../config/environment"

check_for_jobs_interval = ARGV[0]         ? ARGV[0] : 5
additional_conditions = ARGV[1].empty?    ? ''  :  "#{ARGV[1]} and "
log_name = ARGV[2].empty?                 ? ''  :  ".#{ARGV[2]}"

RAILS_DEFAULT_LOGGER = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}.background#{log_name}.log")
ActiveRecord::Base.logger = RAILS_DEFAULT_LOGGER
ActionController::Base.logger = RAILS_DEFAULT_LOGGER
ActionMailer::Base.logger = RAILS_DEFAULT_LOGGER

Signal.trap("TERM") { exit }

if Job.included_modules.include?(Job::BonusFeatures)
  RAILS_DEFAULT_LOGGER.info("BackgroundFu: Starting daemon (bonus features enabled).")
else
  RAILS_DEFAULT_LOGGER.info("BackgroundFu: Starting daemon (bonus features disabled).")
end

loop do
  job = nil
  Job.transaction do
    RAILS_DEFAULT_LOGGER.debug("----- starting transaction to find pending jobs -----")
    job = Job.find(:first, :conditions => ["#{additional_conditions}state='pending' and start_at <= ?", Time.now.utc], :order => "priority desc, start_at asc", :lock => true)
    if job
      job.state = 'starting'
      job.save
    end
    RAILS_DEFAULT_LOGGER.debug("----- finishing transaction to find pending jobs -----")
  end

  if job
    job.get_done!
  end
  
  RAILS_DEFAULT_LOGGER.debug("BackgroundFu: Waiting #{check_for_jobs_interval} seconds for more jobs...")
  sleep check_for_jobs_interval

  
  Job.destroy_all(["state='finished' and updated_at < ?", 1.week.ago])
end
