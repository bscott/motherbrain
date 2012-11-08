module MotherBrain
  # @author Justin Campbell <justin@justincampbell.me>
  #
  # Allows for MotherBrain clients to lock a chef resource. A mutex is created
  # with a name. Sending #lock to the mutex will then store a data bag item
  # with mutex name, chef_connection.client_name, and the current time.
  # An attempt to lock an already-locked name will fail if the lock
  # is owner by someone else, or succeed if the lock is owned by the current
  # user.
  #
  # @example Creating a mutex and obtaining a lock
  #
  #   mutex = ChefMutex.new "my_resource", chef_connection
  #
  #   mutex.lock # => true
  #   # do stuff
  #   mutex.unlock # => true
  #
  # @example Running a block within an obtained lock
  #
  #   mutex = ChefMutex.new "my_resource", chef_connection
  #
  #   mutex.synchronize do
  #     # do stuff
  #   end
  #
  class ChefMutex
    DATA_BAG = "_motherbrain_locks_"

    attr_reader :chef_connection, :client_name, :name

    # @param [#to_s] name
    # @param [Ridley::Connection] chef_connection
    def initialize(name, chef_connection)
      @chef_connection = chef_connection
      @client_name = chef_connection.client_name
      @name = name
    end

    # Attempts to create a lock. Fails if the lock already exists.
    #
    # @return [Boolean]
    def lock
      return true if externally_testing?

      attempt_lock
    end

    # Obtains a lock, runs the block, and releases the lock when the block
    # completes.
    def synchronize(&block)
      begin
        raise ResourceLocked.new(read) unless lock
        yield
      ensure
        unlock
      end
    end

    # Attempts to unlock the lock. Fails if the lock doesn't exist, or if it is
    # held by someone else
    #
    # @return [Boolean]
    def unlock
      return true if externally_testing?

      attempt_unlock
    end

    private

      # @return [Boolean]
      def attempt_lock
        current_lock = read

        return current_lock["client_name"] == client_name if current_lock

        write
      end

      # @return [Boolean]
      def attempt_unlock
        current_lock = read

        return unless current_lock
        return unless current_lock["client_name"] == client_name

        delete
      end

      # @return [Ridley::ChainLink]
      def data_bag
        chef_connection.data_bag
      end

      # Delete the lock from the data bag.
      #
      # @return [Boolean]
      def delete
        return true unless locks

        locks.delete name
      end

      # Create our data bag if it doesn't already exist
      def ensure_data_bag_exists
        data_bag.create name: DATA_BAG unless locks
      end

      def externally_testing?
        ENV['RUBY_ENV'] == 'test'
      end

      # @return [Ridley::DBIChainLink] if the data bag exists
      # @return [nil] if it does not
      def locks
        result = data_bag.find DATA_BAG

        return unless result

        result.item
      end

      # Read the lock from the data bag.
      #
      # @return [Hash] if the lock exists
      # @return [nil] if it does not
      def read
        return unless locks

        result = locks.find name

        result.to_hash if result
      end

      # Write the lock to the data bag.
      #
      # @return [Boolean]
      def write
        ensure_data_bag_exists

        current_lock = locks.new id: name, client_name: client_name, time: Time.now
        current_lock.save
      end
  end
end