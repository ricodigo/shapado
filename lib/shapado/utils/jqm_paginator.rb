module Shapado
  module Utils
    class JqmPaginator < WillPaginate::ViewHelpers::LinkRenderer
      def link(text, target, attributes = {})
        attributes["data-role"] = "button"
        super(text, target, attributes)
      end
    end
  end
end