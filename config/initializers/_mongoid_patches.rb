module Mongoid
  module State
    alias :new? :new_record?
  end
end

module Mongoid
  module Keys
    module ClassMethods
      def key(*args)
        raise ArgumentError, "Attempt to define a field with #{args.inspect}"
      end
    end
  end
end
