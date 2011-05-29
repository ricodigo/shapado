class TopGroupsWidget < Widget
  field :settings, :type => Hash, :default => { :limit => 5, :on_mainlist => true  }

  def top_groups
    Group.where({:state => "active", :private => false, :isolate => false}).
          order_by(:activity_rate.desc).limit(self[:settings]['limit'])
  end

  protected
end
