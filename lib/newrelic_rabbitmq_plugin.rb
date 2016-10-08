require "newrelic_rabbitmq_plugin/version"
require 'uri'
require 'cgi'
require "newrelic_plugin"
require "faraday"
require "faraday_middleware"

module NewrelicRabbitmqPlugin
  class Agent < NewRelic::Plugin::Agent::Base
    agent_guid "com.iora.newrelic_plugin.rabbitmq"
    agent_version NewrelicRabbitmqPlugin::VERSION
    agent_config_options :name, :uri, :debug
    agent_human_labels("RabbitMQ") do
      u = ::URI.parse(uri)
      name || "#{u.host}:#{u.port}"
    end

    def setup_metrics
      @messages_published = NewRelic::Processor::EpochCounter.new
      @messages_acked = NewRelic::Processor::EpochCounter.new
      @messages_delivered = NewRelic::Processor::EpochCounter.new
      @messages_confirmed = NewRelic::Processor::EpochCounter.new
      @messages_redelivered = NewRelic::Processor::EpochCounter.new
      @messages_noacked = NewRelic::Processor::EpochCounter.new
      @bytes_in = NewRelic::Processor::EpochCounter.new
      @bytes_out = NewRelic::Processor::EpochCounter.new
    end

    def poll_cycle
      begin
        if "#{self.debug}" == "true" 
          puts "[RabbitMQ] Debug Mode On: Metric data will not be sent to new relic"
        end

        response = conn.get("/api/overview")

        statistics = response.body

        report_metric_check_debug "Queues/Queued", "Messages", statistics.fetch("queue_totals").fetch("messages")
        report_metric_check_debug "Queues/Ready", "Messages", statistics.fetch("queue_totals").fetch("messages_ready")
        report_metric_check_debug "Queues/Unacknowledged", "Messages", statistics.fetch("queue_totals").fetch("messages_unacknowledged")

        statistics.fetch("object_totals").each do |key, value|
          report_metric_check_debug "Objects/#{key.capitalize}", key, value
        end

        report_metric_check_debug "Messages/Publish", "Messages/Second", @messages_published.process(statistics.fetch("message_stats").fetch("publish"))
        report_metric_check_debug "Messages/Ack", "Messages/Second", @messages_acked.process(statistics.fetch("message_stats").fetch("ack"))
        report_metric_check_debug "Messages/Deliver", "Messages/Second", @messages_delivered.process(statistics.fetch("message_stats").fetch("deliver_get"))
        report_metric_check_debug "Messages/Confirm", "Messages/Second", @messages_confirmed.process(statistics.fetch("message_stats").fetch("confirm"))
        report_metric_check_debug "Message Rate/Return", "Messages/Second", @messages_confirmed.process(statistics.fetch("message_stats").fetch("return_unroutable")) 
        report_metric_check_debug "Messages/Redeliver", "Messages/Second", @messages_redelivered.process(statistics.fetch("message_stats").fetch("redeliver"))
        report_metric_check_debug "Messages/NoAck", "Messages/Second", @messages_noacked.process(statistics.fetch("message_stats").fetch("get_no_ack"))


        response = conn.get("/api/queues")
        statistics = response.body
        statistics.each do |q|
            next if q['name'].start_with?('amq.gen')
            report_metric_check_debug 'Queue' + q.fetch("vhost") + q.fetch("name") + '/Messages/Ready', 'message', q.fetch("messages_ready")
            report_metric_check_debug 'Queue' + q.fetch("vhost") + q.fetch("name") + '/Memory', 'bytes', q.fetch("memory")
            report_metric_check_debug 'Queue' + q.fetch("vhost") + q.fetch("name") + '/Messages/Total', 'message', q.fetch("messages")
            report_metric_check_debug 'Queue' + q.fetch("vhost") + q.fetch("name") + '/Consumers/Total', 'consumers', q.fetch("consumers")
            report_metric_check_debug 'Queue' + q.fetch("vhost") + q.fetch("name") + '/Consumers/Active', 'consumers', q.fetch("active_consumers")
          end

        response = conn.get("/api/nodes")
        statistics = response.body
        statistics.each do |node|
          report_metric_check_debug "Node/MemoryUsage/#{node.fetch("name")}", "Percentage", (node.fetch("mem_used").to_f / node.fetch("mem_limit"))
          report_metric_check_debug "Node/ProcUsage/#{node.fetch("name")}", "Percentage", (node.fetch("proc_used").to_f / node.fetch("proc_total"))
          report_metric_check_debug "Node/FdUsage/#{node.fetch("name")}", "Percentage", (node.fetch("fd_used").to_f / node.fetch("fd_total"))
          report_metric_check_debug "Node/Type/#{node.fetch("name")}", "Type", node.fetch("type")
          report_metric_check_debug "Node/Running/#{node.fetch("name")}", "Running", node.fetch("running") ? 1 : 0
          report_metric_check_debug "Node/Sockets/#{node.fetch("name")}", "Sockets", node.fetch('sockets_used')
        end

      rescue Exception => e
        $stderr.puts "[RabbitMQ] Exception while processing metrics. Check configuration."
        $stderr.puts e.message  
        if "#{self.debug}" == "true"
          $stderr.puts e.backtrace.inspect
        end
      end
    end

    def report_metric_check_debug(metricname, metrictype, metricvalue)
      if "#{self.debug}" == "true"
        puts("#{metricname}[#{metrictype}] : #{metricvalue}")
      else
        report_metric metricname, metrictype, metricvalue
      end
    end

    def conn
      @conn ||= Faraday.new(url: uri) do |conn|
        u = ::URI.parse(uri)
        conn.basic_auth(u.user, u.password)

        conn.response :json, :content_type => /\bjson$/

        conn.use Faraday::Response::RaiseError
        conn.adapter Faraday.default_adapter
      end
    end
  end

  def self.run
    NewRelic::Plugin::Config.config.agents.keys.each do |agent|
      NewRelic::Plugin::Setup.install_agent agent, self
    end

    NewRelic::Plugin::Run.setup_and_run
  end
end

