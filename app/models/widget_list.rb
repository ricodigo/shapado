class WidgetList
  include Mongoid::Document

  POSITIONS = %w[header footer navbar sidebar]

  embedded_in :group_mainlist_widgets, :inverse_of => :mainlist_widgets

  embeds_many :header, :class_name => "Widget", :as => "header_widgets"
  embeds_many :footer, :class_name => "Widget", :as => "footer_widgets"
  embeds_many :navbar, :class_name => "Widget", :as => "navbar_widgets"
  embeds_many :sidebar, :class_name => "Widget", :as => "sidebar_widgets"

  def up
    self.move_to("up")
  end

  def down
    self.move_to("down")
  end

  def move_to(pos, widget_id, context)
    pos ||= "up"
    widgets = self.send(context)
    widget = widgets.find(widget_id)
    current_pos = widgets.index(widget)

    if pos == "up"
      pos = current_pos-1
    elsif pos == "down"
      pos = current_pos+1
    end

    if pos >= widgets.count
      pos = 0
    elsif pos < 0
      pos = widgets.count-1
    end

    widgets[current_pos], widgets[pos] = widgets[pos], widgets[current_pos]

    self.send(:"context=",widgets.to_a)

    self._parent.raw_save(:force => true)
  end
end
