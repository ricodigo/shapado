module Support
module Versionable
  def self.included(klass)
    klass.class_eval do
      extend ClassMethods
      include InstanceMethods

      attr_accessor :rolling_back
      field :version_message

      field :versions_count, :type => Integer, :default => 0
      field :version_ids, :type => Array

      before_save :save_version, :if => Proc.new { |d| !d.rolling_back }
    end
  end

  module InstanceMethods
    def rollback!(pos = nil)
      pos = self.versions_count-1 if pos.nil?
      version = self.version_at(pos)

      if version
        version.data.each do |key, value|
          self.send("#{key}=", value)
        end
        self.updated_by_id = version.user_id unless self.updated_by_id_changed?
        self.updated_at = version.date unless self.updated_at_changed?
      end

      @rolling_back = true
      save!
    end

    def load_version(pos = nil)
      pos = self.versions_count-1 if pos.nil?
      version = self.version_at(pos)

      if version
        version.data.each do |key, value|
          self.send("#{key}=", value)
        end
      end
    end

    def diff(key, pos1, pos2, format = :html)
      version1 = self.version_at(pos1)
      version2 = self.version_at(pos2)

      Differ.diff_by_word(version1.content(key), version2.content(key)).format_as(format).html_safe
    end

    def current_version
      version_klass.new(:data => self.attributes, :user_id => (self.updated_by_id_was || self.updated_by_id), :created_at => Time.now)
    end

    def version_at(pos)
      case pos.to_s
      when "current"
        current_version
      when "first"
        version_klass.find(self.version_ids.first)
      when "last"
        version_klass.find(self.version_ids.last)
      else
        version_klass.find(self.version_ids[pos])
      end
    end

    def versions
      version_klass.where(:target_id => self.id)
    end

    def version_klass
      self.class.version_klass
    end
  end

  module ClassMethods
    def version_klass
      parent_klass = self
      @version_klass ||= Class.new do
        include Mongoid::Document
        include Mongoid::Timestamps

        cattr_accessor :parent_class
        self.parent_class = parent_klass

        self.collection_name = "#{self.parent_class.collection_name}.versions"

        identity :type => String
        field :message, :type => String
        field :data, :type => Hash
        field :user_id, :type => String
        referenced_in :user

        referenced_in :target, :polymorphic => true

        after_create :add_version

        validates_presence_of :target_id

        def content(key)
          cdata = self.data[key]
          if cdata.respond_to?(:join)
            cdata.join(" ")
          else
            cdata || ""
          end
        end

        private
        def add_version
          self.class.parent_class.push({:_id => self.target_id}, {:version_ids => self.id})
          self.class.parent_class.increment({:_id => self.target_id}, {:versions_count => 1})
        end
      end
    end

    def versionable_keys(*keys)
      define_method(:save_version) do
        data = {}
        message = ""
        keys.each do |key|
          if change = changes[key.to_s]
            data[key.to_s] = change.first
          else
            data[key.to_s] = self[key]
          end
        end

        if message_changes = self.changes["version_message"]
          message = message_changes.first
        else
          version_message = ""
        end

        if !self.new? && !data.empty? && self.updated_by_id
          self.version_klass.create({
            'data' => data,
            'user_id' => (self.updated_by_id_was || self.updated_by_id),
            'target' => self,
            'message' => message
          })
        end
      end

      define_method(:versioned_keys) do
        keys
      end
    end
  end
end
end

