class MembershipList < Hash
  def get(group_id)
    m = self[group_id]

    if m && !m.kind_of?(Membership)
      m = self[group_id] = Membership.new(m)
    end

    m
  end

  def groups(conditions = {})
    Group.where(conditions.merge({:_id.in => self.keys}))
  end
end
