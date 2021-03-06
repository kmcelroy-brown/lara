class InteractivePage < ActiveRecord::Base
  attr_accessible :lightweight_activity, :name, :position, :text, :layout, :sidebar, :show_introduction, :show_sidebar,
                  :show_interactive, :show_info_assessment, :embeddable_display_mode, :sidebar_title, :is_hidden,
                  :additional_sections, :is_completion

  serialize :additional_sections

  belongs_to :lightweight_activity, :class_name => 'LightweightActivity', :touch => true

  acts_as_list :scope => :lightweight_activity

  LAYOUT_OPTIONS = [{ :name => 'Full Width',               :class_val => 'l-full-width' },
                    { :name => '60-40',                    :class_val => 'l-6040' },
                    { :name => '70-30',                    :class_val => 'l-7030' },
                    { :name => '60-40 (interactive left)', :class_val => 'r-4060' },
                    { :name => '70-30 (interactive left)', :class_val => 'r-3070' },
                    { :name => 'Responsive', :class_val => 'l-responsive' }]

  EMBEDDABLE_DISPLAY_OPTIONS = ['stacked','carousel']

  INTERACTIVE_BOX = 'interactive_box'

  validates :sidebar_title, presence: true
  validates :layout, :inclusion => { :in => LAYOUT_OPTIONS.map { |l| l[:class_val] } }
  validates :embeddable_display_mode, :inclusion => { :in => EMBEDDABLE_DISPLAY_OPTIONS }

  # Reject invalid HTML inputs
  # See https://www.pivotaltracker.com/story/show/60459320
  validates :text, :sidebar, :html => true

  # PageItem is a join model; if this is deleted, it should go too
  has_many :page_items, :order => [:section, :position], :dependent => :destroy, :include => [:embeddable]

  # Interactive page can register additional page sections:
  #
  #  InteractivePage.register_page_section({name: 'FooBar', dir: 'foo_bar', label: 'Foo Bar'})
  #
  # Each section is required to provide two partials:
  # - #{dir}/_author.html.haml
  # - #{dir}/_runtime.html.haml
  #
  # Note that content of the section is totally flexible.
  # If you want to display some embeddables in section, you can provide 'section' argument to
  # .add_embeddable method and then obtain section embeddables using .section_embeddables method.
  @registered_additional_sections = []
  def self.registered_additional_sections
    @registered_additional_sections
  end

  def self.register_additional_section(s)
    @registered_additional_sections.push(s)
    # Let client code use .update_attributes methods (and similar) to set show_<section_name>.
    attr_accessible "show_#{s[:name]}"
    # show_<section_name> getter:
    define_method("show_#{s[:name]}") do
      additional_sections && additional_sections[s[:name]]
    end
    # show_<section_name> setter:
    define_method("show_#{s[:name]}=") do |v|
      self.additional_sections ||= {}
      # Handle parameter values from Rails forms.
      if v == "1" || v == 1 || v == true
        additional_sections[s[:name]] = true
      else
        additional_sections.delete(s[:name])
      end
    end
  end

  # Register additional sections of interactive page.
  # This code could (or should) to some config file or initializer, but as we
  # have only one additional section at the moment, let's keep it here.
  InteractivePage.register_additional_section({name:  CRater::ARG_SECTION_NAME,
                                               dir:   CRater::ARG_SECTION_DIR,
                                               label: CRater::ARG_SECTION_LABEL})

  # This is a sort of polymorphic has_many :through.
  def embeddables
    page_items.collect{ |qi| qi.embeddable }
  end

  def interactives
    embeddables.select{ |e| Embeddable::is_interactive?(e) }
  end

  def section_embeddables(section)
    page_items.where(section: section).collect{ |qi| qi.embeddable }
  end

  def main_embeddables
    # Embeddables that do not have section specified (nil section).
    section_embeddables(nil)
  end

  def main_questions
    section_embeddables(nil).select{ |e| Embeddable::is_question?(e) }
  end

  def visible_embeddables
    embeddables.select{ |e| !e.is_hidden }
  end

  def visible_interactives
    interactives.select{ |e| !e.is_hidden }
  end

  def section_visible_embeddables(section)
    section_embeddables(section).select{ |e| !e.is_hidden }
  end

  def main_visible_embeddables
    # Visible embeddables that do not have section specified (nil section).
    section_visible_embeddables(nil)
  end

  def interactive_box_embeddables
    section_embeddables(INTERACTIVE_BOX)
  end

  def interactive_box_visible_embeddables
    section_visible_embeddables(INTERACTIVE_BOX)
  end

  def reportable_items
    visible_embeddables.select { |item| item.reportable? }
  end

  def add_embeddable(embeddable, position = nil, section = nil)
    join = PageItem.create!(:interactive_page => self, :embeddable => embeddable,
                            :position => position, :section => section)
    unless position
      join.move_to_bottom
    end
  end

  def add_interactive(interactive, position = nil, validate = true)
    self[:show_interactive] = true
    self.save!(validate: validate)
    add_embeddable(interactive, position, INTERACTIVE_BOX)
  end

  def next_visible_page
    lightweight_activity.visible_pages.where('position > ?', position).first
  end

  def prev_visible_page
    lightweight_activity.visible_pages.where('position < ?', position).last
  end

  def first_visible?
    !is_hidden && prev_visible_page == nil
  end

  def last_visible?
    !is_hidden && next_visible_page == nil
  end

  def visible_sections
    return [] unless additional_sections
    self.class.registered_additional_sections.select { |s| additional_sections[s[:name]] }
  end

  def to_hash
    # Intentionally leaving out:
    # - lightweight_activity association will be added there
    # - user will get the new user
    # - Associations will be done later
    {
      name: name,
      position: position,
      text: text,
      layout: layout,
      is_hidden: is_hidden,
      sidebar: sidebar,
      sidebar_title: sidebar_title,
      show_introduction: show_introduction,
      show_sidebar: show_sidebar,
      show_interactive: show_interactive,
      show_info_assessment: show_info_assessment,
      embeddable_display_mode: embeddable_display_mode,
      additional_sections: additional_sections,
      is_completion: is_completion
    }
  end

  def set_list_position(index)
    # Overloads the acts_as_list version
    self.position = index
    self.save!(:validate => false) # This is the part we need to override
  end

  def page_number
    lightweight_activity.visible_page_ids.index(self.id) + 1
  end

  def duplicate(interactives_cache=nil)
    interactives_cache = InteractivesCache.new if interactives_cache.nil?
    new_page = InteractivePage.new(self.to_hash)
    helper = LaraSerializationHelper.new()

    InteractivePage.transaction do
      new_page.save!(validate: false)

      # Preprocess interactives. We need to do that before we start processing any question.
      self.interactives.each do |inter|
        copy = inter.duplicate
        interactives_cache.set(helper.key(inter), copy)
        if inter.respond_to?(:linked_interactive=) && inter.linked_interactive
          linked_key = helper.key(inter.linked_interactive)
          copy.linked_interactive = interactives_cache.get(linked_key)
          if !copy.linked_interactive
            copy.linked_interactive = inter.linked_interactive.duplicate
            interactives_cache.set(linked_key, copy.linked_interactive)
          end
        end
        helper.cache_item_copy(inter, copy)
      end

      self.embeddables.each do |embed|
        copy = embed.duplicate
        # Interactives
        if Embeddable::is_interactive?(embed)
          inter_copy = helper.lookup_new_item(embed)
          new_page.add_embeddable(inter_copy, nil, embed.page_section)
        end
        # Questions
        if Embeddable::is_question?(embed)
          if embed.respond_to? :interactive=
            unless embed.interactive.nil?
              copy.interactive = helper.lookup_new_item(embed.interactive)
            end
          end
          copy.save!(validate: false)
          if embed.respond_to? :question_tracker and embed.question_tracker
            embed.question_tracker.add_question(copy)
          end
          new_page.add_embeddable(copy, nil, embed.page_section)
        end
      end
    end
    new_page.reload
  end

  def export
    helper = LaraSerializationHelper.new
    page_json = self.as_json(only: [:name,
                                    :position,
                                    :text,
                                    :layout,
                                    :is_hidden,
                                    :sidebar,
                                    :sidebar_title,
                                    :show_introduction,
                                    :show_sidebar,
                                    :show_interactive,
                                    :show_info_assessment,
                                    :embeddable_display_mode,
                                    :additional_sections,
                                    :is_completion])
    page_json[:embeddables] = []

    self.embeddables.each do |embed|
      embeddable_hash = helper.wrap_export(embed)
      if embed.respond_to? :linked_interactive
        embeddable_hash[:linked_interactive] = embed.linked_interactive.present? ? helper.wrap_export(embed.linked_interactive) : nil
      end
      page_json[:embeddables] << { embeddable: embeddable_hash, section: embed.page_section }
    end

    page_json
  end

  def self.extact_from_hash(page_json_object)
    #pages = activity_json_object[:pages]
    import_simple_attributes = [
      :name,
      :position,
      :text,
      :layout,
      :is_hidden,
      :sidebar,
      :sidebar_title,
      :show_introduction,
      :show_sidebar,
      :show_interactive,
      :show_info_assessment,
      :embeddable_display_mode
    ]

    attributes = {}
    import_simple_attributes.each do |key|
      attributes[key] = page_json_object[key] if page_json_object.has_key?(key)
    end

    attributes
  end

  def self.import(page_json_object, interactives_cache=nil)
    interactives_cache = InteractivesCache.new if interactives_cache.nil?
    helper = LaraSerializationHelper.new
    import_page = InteractivePage.new(self.extact_from_hash(page_json_object))
    InteractivePage.transaction do
      import_page.save!(validate: false)
      # The first pass. Look for all interactives and process them, so they can be referenced by other embeddables later.
      page_json_object[:embeddables].each do |embed_hash|
        embed = embed_hash[:embeddable]
        if Embeddable::is_interactive?(embed[:type].constantize)
          linked_inter = embed[:linked_interactive]
          embed.delete(:linked_interactive)

          import_embeddable = helper.wrap_import(embed)
          interactives_cache.set(embed[:ref_id], import_embeddable)

          if linked_inter
            import_embeddable.linked_interactive = interactives_cache.get(linked_inter[:ref_id])
            if !import_embeddable.linked_interactive
              import_embeddable.linked_interactive = helper.wrap_import(linked_inter)
              interactives_cache.set(linked_inter[:ref_id], import_embeddable.linked_interactive)
            end
            import_embeddable.save!(validate: false)
          end
        end
      end
      # The second pass. Process all the embeddables and add them to page in right order.
      page_json_object[:embeddables].each do |embed_hash|
        embed = embed_hash[:embeddable]
        section = embed_hash[:section]
        import_embeddable = Embeddable::is_interactive?(embed[:type].constantize) ?
          interactives_cache.get(embed[:ref_id]) : helper.wrap_import(embed)
        import_page.add_embeddable(import_embeddable, nil, section)
      end
    end
    return import_page
  end
end
