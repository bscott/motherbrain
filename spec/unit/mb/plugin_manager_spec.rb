require 'spec_helper'

describe MotherBrain::PluginManager do
  describe "ClassMethods" do
    subject { described_class }

    describe "::new" do
      context "when 'remote_loading' is disabled" do
        before(:each) do
          @original = MB::Application.config.plugin_manager.remote_loading
          MB::Application.config.plugin_manager.remote_loading = false
        end

        after(:each) do
          MB::Application.config.plugin_manager.remote_loading = @original
        end

        it "has a nil value for remote_load_timer" do
          subject.new.remote_load_timer.should be_nil
        end
      end

      context "when 'remote_loading' is enabled" do
        before(:each) do
          @original = MB::Application.config.plugin_manager.remote_loading
          MB::Application.config.plugin_manager.remote_loading = true
        end

        after(:each) do
          MB::Application.config.plugin_manager.remote_loading = @original
        end

        it "sets a Timer for remote_load_timer" do
          subject.any_instance.should_receive(:load_all_remote)

          subject.new.remote_load_timer.should be_a(Timers::Timer)
        end
      end
    end
  end

  subject { described_class.new }

  describe "#load_all" do
    let(:paths) do
      [
        tmp_path.join('plugin_one'),
        tmp_path.join('plugin_two'),
        tmp_path.join('plugin_three')
      ]
    end

    before(:each) do
      subject.clear_plugins
      paths.each do |path|
        generate_cookbook(SecureRandom.hex(16), path, with_plugin: true)
      end

      MB::Berkshelf.stub(:cookbooks).and_return(paths)
    end

    it "sends a load message to self with each plugin found in the berkshelf" do
      subject.should_receive(:load_file).with(anything, force: false).exactly(3).times

      subject.load_all
    end

    it "has a plugin for each plugin in the paths" do
      subject.load_all

      subject.plugins.should have(3).items
      subject.plugins.should each be_a(MB::Plugin)
    end

    context "when 'remote_loading' is enabled" do
      before(:each) do
        @original = MB::Application.config.plugin_manager.remote_loading
        MB::Application.config.plugin_manager.remote_loading = true
      end

      after(:each) do
        MB::Application.config.plugin_manager.remote_loading = @original
      end

      it "calls #load_all_remote" do
        subject.should_receive(:load_all_remote)
        subject.load_all
      end
    end
  end

  describe "#load_file" do
    let(:plugin) do
      metadata = MB::CookbookMetadata.new do
        name 'apple'
        version '1.0.0'
      end
      MB::Plugin.new(metadata)
    end

    let(:path) { '/tmp/one/apple-1.0.0' }

    before(:each) do
      MB::Plugin.stub(:from_path).with(path).and_return(plugin)
    end

    it "adds an instantiated plugin to the hash of plugins" do
      subject.load_file(path)

      subject.plugins.should include(plugin)
    end
  end

  describe "#load_resource" do
    let(:client) { double('client') }
    let(:resource) do
      Ridley::CookbookResource.new(client)
    end

    context "when the resource doesn't contain a motherbrain plugin" do
      before(:each) { resource.stub(has_motherbrain_plugin?: false) }

      it "returns nil if resource doesn't contain a motherbrain plugin" do
        subject.load_resource(resource).should be_nil
      end
    end

    context "when resource contains a motherbrain plugin" do
      before(:each) { resource.stub(has_motherbrain_plugin?: true) }
      let(:temp_dir) { MB::FileSystem.tmpdir }

      context "and the files are transferred successfully" do
        before(:each) do
          generate_cookbook('whatever', temp_dir, with_plugin: true)
          MB::FileSystem.stub(:tmpdir) { temp_dir }
          metadata = File.join(temp_dir, MB::Plugin::PLUGIN_FILENAME)
          plugin = File.join(temp_dir, MB::Plugin::METADATA_FILENAME)

          resource.stub(:download_file).and_return(true)
        end

        it "adds the plugin to the set of plugins" do
          subject.load_resource(resource)

          subject.plugins.should have(1).item
        end

        it "cleans up the generated temporary files" do
          subject.load_resource(resource)

          File.exist?(temp_dir).should be_false
        end
      end

      context "and one or more of the files is not transferred successfully" do
        before(:each) { resource.stub(:download_file).and_return(nil) }

        it "raises a PluginDownloadError" do
          expect {
            subject.load_resource(resource)
          }.to raise_error(MB::PluginDownloadError)
        end
      end
    end
  end

  describe "#add" do
    let(:plugin) do
      metadata = MB::CookbookMetadata.new do
        name 'apple'
        version '1.0.0'
      end
      MB::Plugin.new(metadata)
    end

    it "returns a Set of plugins" do
      result = subject.add(plugin)

      result.should be_a(Set)
      result.should each be_a(MB::Plugin)
    end

    it "adds the plugin to the Set of plugins" do
      subject.add(plugin)

      subject.plugins.should include(plugin)
    end

    context "when the plugin is already added" do
      it "returns nil" do
        subject.add(plugin)
        
        subject.add(plugin).should be_nil
      end

      context "when given 'true' for the ':force' option" do
        it "adds the plugin anyway" do
          subject.add(plugin)
          result = subject.add(plugin, force: true)

          result.should be_a(Set)
          result.should include(plugin)
        end
      end
    end
  end

  describe "#find" do
    let(:one) do
      metadata = MB::CookbookMetadata.new do
        name 'apple'
        version '1.0.0'
      end
      MB::Plugin.new(metadata)
    end
    let(:two) do
      metadata = MB::CookbookMetadata.new do
        name 'apple'
        version '2.0.0'
      end
      MB::Plugin.new(metadata)
    end
    let(:three) do
      metadata = MB::CookbookMetadata.new do
        name 'orange'
        version '2.0.0'
      end
      MB::Plugin.new(metadata)
    end

    before(:each) do
      subject.add(one)
      subject.add(two)
      subject.add(three)
    end

    context "when a version is given" do
      it "returns the plugin of the given name and version" do
        subject.find(one.name, one.version).should eql(one)
      end

      it "returns nil if the plugin of a given name and version is not found" do
        subject.find("glade", "3.2.4").should be_nil
      end
    end

    context "when no version is given" do
      it "returns the latest version of the plugin" do
        subject.find(two.name).should eql(two)
      end

      it "returns nil a plugin of the given name is not found" do
        subject.find("glade").should be_nil
      end
    end
  end

  describe "#clear_plugins" do
    let(:plugin) do
      metadata = MB::CookbookMetadata.new do
        name 'apple'
        version '1.0.0'
      end
      MB::Plugin.new(metadata)
    end

    it "clears any loaded plugins" do
      subject.add(plugin)
      subject.clear_plugins

      subject.plugins.should be_empty
    end
  end
end
