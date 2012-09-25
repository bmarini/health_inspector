# encoding: UTF-8
require "pathname"

module HealthInspector
  module Checklists
    class Base
      include Color

      class << self
        attr_reader :checks, :title

        def add_check(name, &block)
          @checks ||= []
          @checks << block
        end

        def title(val=nil)
          val.nil? ? @title : @title = val
        end
      end

      def self.run(context)
        new(context).run
      end

      def initialize(context)
        @context = context
      end

      def run
        banner "Inspecting #{self.class.title}"

        items.each do |item|
          failures = run_checks(item)

          if failures.empty?
            print_success(item.name)
          else
            print_failures(item.name, failures)
          end
        end
      end

      def run_checks(item)
        checks.map { |check| run_check(check, item) }.compact
      end

      def checks
        self.class.checks
      end

      class CheckContext
        include Check, Color
        attr_accessor :item, :context

        def initialize(check, item, context)
          @item = item
          @context = context
          @check = check
        end

        def call
          instance_eval(&@check)
        end

        def diff(original, other)
          (original.keys + other.keys).uniq.inject({}) do |memo, key|
            unless original[key] == other[key]
              if original[key].kind_of?(Hash) && other[key].kind_of?(Hash)
                memo[key] = diff(original[key], other[key])
              else
                memo[key] = [original[key], other[key]]
              end
            end
            memo
          end
        end
      end

      def run_check(check, item)
        check_context = CheckContext.new(check, item, @context)
        check_context.call
        return check_context.failure
      end

      def banner(message)
        puts
        puts message
        puts "-" * 80
      end

      def print_success(subject)
        puts color('bright pass', "✓") + " #{subject}"
      end

      def print_failures(subject, failures)
        puts color('bright fail', "- #{subject}")

        failures.each do |message|
          puts color('bright yellow', "  #{message}")
        end
      end

      def load_ruby_or_json_from_local(chef_class, folder, name)
        path_template = "#{@context.repo_path}/#{folder}/#{name}.%s"
        ruby_pathname = Pathname.new(path_template % "rb")
        json_pathname = Pathname.new(path_template % "json")
        js_pathname   = Pathname.new(path_template % "js")

        if ruby_pathname.exist?
          instance = chef_class.new
          instance.from_file(ruby_pathname.to_s)
        elsif json_pathname.exist?
          instance = chef_class.json_create( Yajl::Parser.parse( json_pathname.read ) )
        elsif js_pathname.exist?
          instance = chef_class.json_create( Yajl::Parser.parse( js_pathname.read ) )
        end

        instance ? instance.to_hash : nil
      rescue IOError
        nil
      end

    end
  end
end
