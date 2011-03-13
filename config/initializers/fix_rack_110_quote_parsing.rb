# Replacements for the Rack::Utils parse_query and normalize_params methods.
# Code is from Rack 1.1.0 with the patch at 
# http://github.com/rack/rack/commit/dae12e088592ee69545b5f2f81b87f4959859164
# applied.
#
# Fixes a bug where pairs of quotes in parameter values cause the parameter
# to be truncated. See:
# https://rails.lighthouseapp.com/projects/8994/tickets/4808-textarea-input-silently-truncated-in-238

rack_spec = Gem.loaded_specs['rack']

if rack_spec && rack_spec.version.version == '1.1.0'
  module Rack
    module Utils
      def parse_query(qs, d = nil)
        params = {}

        (qs || '').split(d ? /[#{d}] */n : DEFAULT_SEP).each do |p|
          k, v = p.split('=', 2).map { |x| unescape(x) }
          if cur = params[k]
            if cur.class == Array
              params[k] << v
            else
              params[k] = [cur, v]
            end
          else
            params[k] = v
          end
        end

        return params
      end
      module_function :parse_query

      def normalize_params(params, name, v = nil)
        name =~ %r(\A[\[\]]*([^\[\]]+)\]*)
        k = $1 || ''
        after = $' || ''

        return if k.empty?

        if after == ""
          params[k] = v
        elsif after == "[]"
          params[k] ||= []
          raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
          params[k] << v
        elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
          child_key = $1
          params[k] ||= []
          raise TypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
          if params[k].last.is_a?(Hash) && !params[k].last.key?(child_key)
            normalize_params(params[k].last, child_key, v)
          else
            params[k] << normalize_params({}, child_key, v)
          end
        else
          params[k] ||= {}
          raise TypeError, "expected Hash (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Hash)
          params[k] = normalize_params(params[k], after, v)
        end

        return params
      end
      module_function :normalize_params
    end
  end
else
  Rails.logger.warn 'fix_rack_110_quote_parsing.rb not loaded'
end
