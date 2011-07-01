class UsersWidget < Widget
  field :settings, :type => Hash, :default => { :limit => 5, :on_mainlist => true  }


  def recent_users(group)
    group.memberships.order_by(%W[created_at desc]).limit(self[:settings]['limit']).
      paginate(:per_page => self[:settings]['limit'], :page => 1)
  end

  protected
end
