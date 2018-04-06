# encoding: UTF-8
#
#
# Define all common mungers available for all types
#
module EasyType
  #
  # The Integer munger, munges a specified value to an Integer.
  #
  module Mungers

    [Integer, String, Array, Float].each do| klass|
      module_eval(<<-END_RUBY, __FILE__, __LINE__)
        # @nodoc
        # @private
        module #{klass}
          def unsafe_munge(value)
            #{klass}(value)
          end
        end
      END_RUBY
    end
    #
    # The Size munger, munges a specified value to an Integer.
    #
    module Size
      # @private
      def unsafe_munge(size)
        return size if size.is_a?(Numeric)
        case size
        when /^\d+(K|k)$/ then size.chop.to_i * 1024
        when /^\d+(M|m)$/ then size.chop.to_i * 1024 * 1024
        when /^\d+(G|g)$/ then size.chop.to_i * 1024 * 1024 * 1024
        when /^\d+$/ then size.to_i
        else
          fail('invalid size')
        end
      end
    end

    #
    # The Upcase and downcase munger, munges a specified value to an specified String
    # If the value is an array, all entries in the array will be managed
    # If the value doesn't support the method, a debug message is send and the original value
    # is returned.
    #
    [:downcase, :upcase].each do| method|
      klass = method.to_s.capitalize
      module_eval(<<-END_RUBY, __FILE__, __LINE__)
        # @nodoc
        # @private
        module #{klass}
          def unsafe_munge(entry)
            if entry.is_a?(::Array)
              entry.collect{|e| #{method}_if_defined(e)}
            else
              #{method}_if_defined(entry)
            end
          end

          private

          def #{method}_if_defined(value)
            if value.respond_to?(:#{method})
              value.#{method}
            else
              Puppet.debug "Found an unsupported #{method} munge."
              value
            end
          end
        end
      END_RUBY
    end
  end
end