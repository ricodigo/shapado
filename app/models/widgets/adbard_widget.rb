class AdbardWidget < Widget
  field :settings, :type => Hash, :default => { 'host_id' => "", 'site_key' => ""}
  validate :has_ads

  def ad
    return "<!--Ad Bard advertisement snippet, begin -->
    <script type='text/javascript'>
    var ab_h = '#{settings['host_id']}';
    var ab_s = '#{settings['site_key']}';
    </script>
    <script type='text/javascript' src='http://cdn1.adbard.net/js/ab1.js'></script>
    <!--Ad Bard, end -->
    ".html_safe
  end

  protected
  def has_ads
    return self.group.has_custom_ads
  end
end

