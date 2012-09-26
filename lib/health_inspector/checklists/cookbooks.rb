module HealthInspector
  module Checklists

    class Cookbooks < Base

      add_check "local copy exists" do
        failure( "exists on chef server but not locally" ) if item.path.nil?
      end

      add_check "server copy exists" do
        failure( "exists locally but not on chef server" ) if item.server_version.nil?
      end

      add_check "versions" do
        if item.local_version && item.server_version &&
           item.local_version != item.server_version
          failure "chef server has #{item.server_version} but local version is #{item.local_version}"
        end
      end

      add_check "uncommitted changes" do
        if item.git_repo?
          result = `cd #{item.path} && git status -s`

          unless result.empty?
            failure "Uncommitted changes:\n#{result.chomp}"
          end
        end
      end

      add_check "commits not pushed to remote" do
        if item.git_repo?
          result = `cd #{item.path} && git status`

          if result =~ /Your branch is ahead of (.+)/
            failure "ahead of #{$1}"
          end
        end
      end

      add_check "changes on the server not in the repo" do
        failure "Your server has a newer version of the file" if false
      end

      class Cookbook < Struct.new(:name, :path, :server_version, :local_version)
        def git_repo?
          self.path && File.exist?("#{self.path}/.git")
        end
      end

      title "cookbooks"

      def items
        server_cookbooks           = cookbooks_on_server
        local_cookbooks            = cookbooks_in_repo
        all_cookbook_names = ( server_cookbooks.keys + local_cookbooks.keys ).uniq.sort
        server_cbs_checksums       = cookbook_checksums_on_server( all_cookbook_names )
        local_cbs_checksums        = cookbook_checksums_in_repo( all_cookbook_names )

        all_cookbook_names.map do |name|
          Cookbook.new.tap do |cookbook|
            cookbook.name           = name
            cookbook.path           = cookbook_path(name)
            cookbook.server_version = server_cookbooks[name]
            cookbook.local_version  = local_cookbooks[name]
          end
        end
      end

      def cookbooks_on_server
        Yajl::Parser.parse( @context.knife_command("cookbook list -Fj") ).inject({}) do |hsh, c|
          name, version = c.split
          hsh[name] = version
          hsh
        end
      end

      def cookbooks_in_repo
        @context.cookbook_path.
          map { |path| Dir["#{path}/*"] }.
          flatten.
          select { |path| File.exists?("#{path}/metadata.rb") }.
          inject({}) do |hsh, path|

          name    = File.basename(path)
          version = (`grep '^version' #{path}/metadata.rb`).split.last[1...-1]

          hsh[name] = version
          hsh
        end
      end

      def cookbook_path(name)
        path = @context.cookbook_path.find { |f| File.exist?("#{f}/#{name}") }
        path ? File.join(path, name) : nil
      end

      def cookbook_checksums_on_server(name)

      end

      def cookbook_checksums_in_repo(name)

      end
    end
  end
end
