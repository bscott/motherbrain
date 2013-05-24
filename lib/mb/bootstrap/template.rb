module MotherBrain
  module Bootstrap
    # @author Michael Ivey <muchael.ivey@riotgames.com>
    #
    class Template
      class << self
        def install(name, filename_or_url)
          if filename_or_url.match(URI.regexp(['http','https']))
            uri = URI.parse(filename_or_url)
            Net::HTTP.start(uri.host) do |http|
              resp = http.get(uri.path)
              MB::FileSystem.templates.join(name).open("w+") do |file|
                file.write(resp.body)
              end
            end
          elsif File.exists?(filename_or_url)
            FileUtils.copy(filename_or_url, MB::FileSystem.templates.join(name).to_s)
          else
            raise MB::BootstrapTemplateNotFound
          end
        end

        def find(name_or_path=nil)
          name_or_path ||= MB::Application.config.bootstrap.default_template
          installed = MB::FileSystem.templates.join("#{name_or_path}.erb").to_s
          if File.exists?(installed)
            return installed
          end
          if File.exists?(name_or_path)
            return name_or_path
          else
            raise MB::BootstrapTemplateNotFound
          end
        end
      end
    end
  end
end
