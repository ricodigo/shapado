class AdsenseWidget < Widget
  field :settings, :type => Hash, :default => { 'client' => "", 'slot' => 0, 'width' => 0, 'height' => 0}
  validate :has_ads

  def ad
    return "<script type=\"text/javascript\"><!--
    google_ad_client = \"#{settings['client']}\";
    google_ad_slot = \"#{settings['slot']}\";
    google_ad_width = #{settings['width']};
    google_ad_height = #{settings['height']};
    //-->
    </script>
    <script type=\"text/javascript\"
    src=\"http://pagead2.googlesyndication.com/pagead/show_ads.js\">
    </script>".html_safe
  end

  protected
  def has_ads
    return self.group.has_custom_ads
  end
end

