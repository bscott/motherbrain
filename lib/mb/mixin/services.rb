module MotherBrain
  module Mixin
    # A mixin to provide easy access to the various services (actors) running in the
    # motherbrain stack.
    module Services
      class << self
        def included(base)
          base.extend(ClassMethods)
          base.send(:include, ClassMethods)
        end

        def extended(base)
          base.send(:include, ClassMethods)
        end
      end

      module ClassMethods
        # @raise [Celluloid::DeadActorError] if the bootstrap manager has not been started
        #
        # @return [Celluloid::Actor(Bootstrap::Manager)]
        def bootstrap_manager
          Bootstrap::Manager.instance
        end
        alias_method :bootstrapper, :bootstrap_manager

        # @raise [Celluloid::DeadActorError] if command invoker has not been started
        #
        # @return [Celluloid::Actor(CommandInvoker)]
        def command_invoker
          CommandInvoker.instance
        end

        # @raise [Celluloid::DeadActorError] if the config manager has not been started
        #
        # @return [Celluloid::Actor(ConfigManager)]
        def config_manager
          ConfigManager.instance
        end

        # @raise [Celluloid::DeadActorError] if the environment manager has not been started
        #
        # @return [Celluloid::Actor(EnvironmentManager)]
        def environment_manager
          EnvironmentManager.instance
        end

        # @raise [Celluloid::DeadActorError] if the job manager has not been started
        #
        # @return [Celluloid::Actor(JobManager)]
        def job_manager
          JobManager.instance
        end

        # @raise [Celluloid::DeadActorError] if the lock manager has not been started
        #
        # @return [Celluloid::Actor(LockManager)]
        def lock_manager
          LockManager.instance
        end

        # @raise [Celluloid::DeadActorError] if the node querier has not been started
        #
        # @return [Celluloid::Actor(NodeQuerier)]
        def node_querier
          NodeQuerier.instance
        end

        # @raise [Celluloid::DeadActorError] if the plugin manager has not been started
        #
        # @return [Celluloid::Actor(PluginManager)]
        def plugin_manager
          PluginManager.instance
        end

        # @raise [Celluloid::DeadActorError] if the provisioner manager has not been started
        #
        # @return [Celluloid::Actor(Provisioner::Manager)]
        def provisioner_manager
          Provisioner::Manager.instance
        end
        alias_method :provisioner, :provisioner_manager

        # @raise [Celluloid::DeadActorError] if Ridley has not been started
        #
        # @return [Celluloid::Actor(Ridley::Connection)]
        def ridley
          MB::Application[:ridley] or raise Celluloid::DeadActorError, "Ridley not running"
        end
        alias_method :chef_connection, :ridley

        # @raise [Celluloid::DeadActorError] if the upgrade manager has not been started
        #
        # @return [Celluloid::Actor(Upgrade::Manager)]
        def upgrade_manager
          Upgrade::Manager.instance
        end
      end
    end
  end
end
