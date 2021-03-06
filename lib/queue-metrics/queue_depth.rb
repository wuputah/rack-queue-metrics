require 'queue-metrics/notify'

module Rack
  module QueueMetrics
    class QueueDepth
      include Notify

      def initialize(app)
        @app = app
        @addr = IPSocket.getaddress(Socket.gethostname).to_s + ':'+ENV['PORT']
        @instrument_name = "rack.queue-metrics.queue-depth"
        Thread.new {report(1)}
      end

      def call(env)
        return @app.call(env) unless ENV['PORT']
        status, headers, body = @app.call(env)
        [status, headers, body]
      end

    private

      def report(interval)
        loop do
          stats = raindrops_stats
          notify(stats) if should_notify?
          $stdout.puts(["measure=#{@instrument_name}",
                        "addr=#{@addr}",
                        "queue_depth=#{stats[:requests][:queued]}"].join(' '))
          sleep(interval)
        end
      end

      def raindrops_stats
        if defined? Raindrops::Linux.tcp_listener_stats
          stats = Raindrops::Linux.tcp_listener_stats([ '0.0.0.0:'+ENV['PORT'] ])['0.0.0.0:'+ENV['PORT']]
          return { :requests => { :active => stats.active, :queued => stats.queued }}
        else
          return { :requests => { :active => 0, :queued => 0 }}
        end
      end

    end
  end
end
