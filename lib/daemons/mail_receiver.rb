#!/usr/bin/env ruby

require 'drb/drb'
require File.dirname(__FILE__) + "/../../config/environment"

$running = true;
Signal.trap("TERM") { $running = false }
logger = ActionMailer::Base.logger

host = ARGV.shift
port = ARGV.shift.to_i
logger.info "daemon #{__FILE__} started at #{RAILS_ENV} environment"
begin
  DRb.start_service("druby://#{host}:#{port}", MailHandler)
  logger.info "waiting at #{host}:#{port}"
  while($running) do
    logger.debug "daemon #{__FILE__} is still running at #{Time.now}."
    sleep 10
  end
  logger.info "daemon #{__FILE__} stopped at #{RAILS_ENV} environment"
ensure
  bt = $!.backtrace.join("\n")
  logger.error "#{$!.message}:#{bt}"
end
