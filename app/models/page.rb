class Page
  include Mongoid::Document
  include MongoidExt::Filter
  include MongoidExt::Slugizer
  include MongoidExt::Tags
  include MongoidExt::Storage
  include Support::Versionable

  include Mongoid::Timestamps
  include Shapado::Models::Trackable

  track_activities :user, :title, :language, :scope => [:group_id]


  identity :type => String
  field :title, :type => String
  field :body, :type => String
  field :wiki, :type => Boolean, :default => false
  field :language, :type => String
  field :adult_content, :type => Boolean, :default => false

  referenced_in :user
  referenced_in :group

  referenced_in :updated_by, :class_name => "User"

  slug_key :title, :unique => true, :min_length => 3

  file_key :js
  file_key :css

  versionable_keys :title, :body, :tags

  validates_presence_of :group
  validates_uniqueness_of :title, :scope => [:group_id, :language]
  validates_uniqueness_of :slug, :scope => [:group_id, :language], :allow_blank => true

  def self.by_title(title, conditions = {})
    self.where(conditions.merge({:title => title, :language => current_language})).first ||
    self.where(conditions.merge(:title => title)).first# ||  # FIXME: mongoid
    self.where(conditions.merge(:language => current_language)).by_slug(title) ||
    self.where(conditions).by_slug(title)
  end

  private
  def self.current_language
    @current_language ||= I18n.locale.to_s.split("-",2).first
  end
end
