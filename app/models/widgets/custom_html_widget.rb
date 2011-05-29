class CustomHtmlWidget < Widget
  field :settings, :type => Hash, :default => {'content' => {}, 'title' =>{}, 'footer'=>{}}

  def content
    settings['content'][I18n.locale.to_s.split("-").first] ||
    settings['content'][self.group.language] || ""
  end

  def title
    settings['title'][I18n.locale.to_s.split("-").first] ||
    settings['title'][self.group.language] || ""
  end

  def footer
    settings['footer'][I18n.locale.to_s.split("-").first] ||
    settings['footer'][self.group.language] || ""
  end
end
