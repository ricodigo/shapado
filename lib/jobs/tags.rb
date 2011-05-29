module Jobs
  class Tags
    extend Jobs::Base

    def self.question_retagged(question_id, new_tags, old_tags, at_time)
      question = Question.find(question_id)
      if !new_tags.blank?
        tags = question.group.tags.where(:name.in => new_tags).only(:name).map(&:name)

        Tag.collection.update({ :name => {:$in => tags}, :group_id => question.group_id },
                              { :$inc => {:count => 1}, :$set => {:used_at => at_time }},
                              { :multi => true })

        (new_tags-tags).each do |name|
          Tag.create!( :name => name, :group_id => question.group_id, :count => 1,
                       :user_id => question.anonymous ? nil : question.user_id,
                       :used_at => at_time, :created_at => at_time, :updated_at => at_time)
        end
      end

      if !old_tags.blank?
        Tag.collection.update({ :name => {:$in => new_tags-old_tags}, :group_id => question.group_id },
                              { :$inc => {:count => -1}})
      end
    end
  end
end
