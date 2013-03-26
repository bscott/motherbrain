module MotherBrain
  module SpecHelpers
    def app_root_path
      Pathname.new(File.expand_path('../../../', __FILE__))
    end

    def app_tmp_path
      app_root_path.join('spec/.mb')
    end

    def berkshelf_path
      MB::Berkshelf.default_path
    end

    def tmp_path
      app_root_path.join('spec/tmp')
    end

    def fixtures_path
      app_root_path.join('spec/fixtures')
    end

    def mocks_path
      app_root_path.join('spec/mocks')
    end

    def clean_tmp_path
      FileUtils.rm_rf(tmp_path)
      FileUtils.mkdir_p(tmp_path)
      FileUtils.rm_rf("#{app_tmp_path}/*")
    end

    def mb_config
      @mb_config ||= MB::Config.new(nil,
        {
          chef: {
            api_url: "http://chef.riotgames.com",
            api_client: "fake",
            api_key: File.join(fixtures_path, "fake_key.pem"),
            validator_client: "fake",
            validator_path: File.join(fixtures_path, "fake_key.pem")
          },
          ssh: {
            user: 'reset',
            password: 'whatever',
            keys: []
          },
          ef: {
            api_key: "asdf",
            api_url: "https://ef.riotgames.com"
          },
          rest_gateway: {
            port: 1985
          },
          plugin_manager: {
            eager_loading: false
          }
        }
      )
    end

    def mb_config_path
      MB::Config.default_path
    end

    def register_mock(hook, mock)
      set_env "motherbrain_mocks_#{hook}", mocks_path.join("#{mock}.rb").to_s
    end

    # @param [String] name
    #   name of the cookbook to generate
    #
    # @option options [String] :path
    #   path to the directory to place the cookbook in
    # @option options [String] :version
    #   version of the cookbook to generate
    # @option options [Boolean] :with_plugin
    #   should this cookbook include a motherbrain plugin?
    #
    # @return [String]
    #   path to the generated cookbook
    def generate_cookbook(name, options = {})
      options = options.reverse_merge(
        version: "0.1.0",
        with_plugin: true
      )

      cookbook_path = options[:path] || File.join(berkshelf_path, 'cookbooks', "#{name}-#{options[:version]}")

      FileUtils.mkdir_p(cookbook_path)
      File.open(File.join(cookbook_path, MB::Plugin::RUBY_METADATA_FILENAME), 'w+') do |f|
        f.write <<-EOH
          name             "#{name}"
          maintainer       "Jamie Winsor"
          maintainer_email "jamie@vialstudios.com"
          license          "Apache 2.0"
          description      "Installs/Configures #{name}"
          long_description "Installs/Configures #{name}"
          version          "#{options[:version]}"

          %w{ ubuntu centos }.each do |os|
            supports os
          end
        EOH
      end

      if options[:with_plugin]
        File.open(File.join(cookbook_path, MB::Plugin::PLUGIN_FILENAME), 'w+') do |f|
          f.write "# #{name} plugin\n"
          if options[:with_bootstrap]
            f.write <<-PLUGIN
cluster_bootstrap do
  bootstrap("#{name}::server")
end

component "#{name}" do
  description "The #{name} service"
  group "server" do
    recipe "#{name}::server"
  end
end
PLUGIN
          end
        end
      end

      cookbook_path
    end

    # @param [String] path
    #
    # @return [MB::Config]
    def generate_valid_config(path = MB::Config.default_path)
      FileUtils.rm_rf(path)
      mb_config.save(path)

      mb_config
    end

    def generate_invalid_config(path)
      FileUtils.rm_rf(path)
      MB::Config.new.save(path)
    end

    def klass
      described_class
    end
  end
end
