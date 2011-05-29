class UserStat
  include Mongoid::Document
  include Mongoid::Timestamps

  identity :type => String

  field :answer_tags, :type => Array, :default => []
  field :question_tags, :type => Array, :default => []
  field :expert_tags, :type => Array, :default => []

  field :tag_votes, :type => Hash, :default => {}

  referenced_in :user

  def add_answer_tags(*tags)
    self.collection.update({:_id => self.id},
                              { :$addToSet => { :answer_tags => { :$each => tags }}})
  end

  def add_question_tags(*tags)
    self.collection.update({:_id => self.id},
                              { :$addToSet => { :question_tags => { :$each => tags }}})
  end

  def add_expert_tags(*tags)
    self.collection.update({:_id => self.id},
                              { :$addToSet => { :expert_tags => { :$each => tags }}})
  end

  def vote_on_tags(tags, inc = 1)
    opts = {}
    tags.each do |tag|
      opts["tag_votes.#{tag}"] = inc
    end
    self.increment(opts)
  end
end
