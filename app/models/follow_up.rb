class FollowUp
  include Mongoid::Document

  identity :type => String

  #belongs_to :original_question, :class_name => "Question"
  #belongs_to :original_answer, :class_name => "Answer"
  field :original_question_id, :type => String
  field :original_answer_id, :type => String

  embedded_in :question, :inverse_of => :follow_up

  validates_presence_of :original_question_id

  def original_question
    Question.find(self.original_question_id)
  end

  def original_answer
    Answer.find(self.original_answer_id)
  end
end
