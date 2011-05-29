module GroupsHelper
  def group_logo_img(group, options)
    options[:alt] ||= group.name
    options[:title] ||= group.name

    begin
      if group.has_logo?
        if options[:size].nil?
          options.merge!(:width => group.logo_info["width"], :height => group.logo_info["height"])
        end
        image_tag(logo_path(current_group), options)
      else
        image_tag("shapado-brand.png", options)
      end
    rescue Exception => e
      Rails.logger.info e.backtrace.join("\n\t")
      image_tag("shapado-brand.png", options)
    end
  end
end
