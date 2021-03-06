class Sequence < ActiveRecord::Base
  attr_accessible :description, :title, :theme_id, :project_id,
    :user_id, :logo, :display_title, :thumbnail_url, :abstract, :publication_hash,
    :external_report_url
  include Publishable # defines methods to publish to portals
  include PublicationStatus # defines publication status scopes and helpers
  has_many :lightweight_activities_sequences, :order => :position, :dependent => :destroy
  has_many :lightweight_activities, :through => :lightweight_activities_sequences, :order => :position
  belongs_to :user
  belongs_to :theme
  belongs_to :project

  has_many :imports, as: :import_item

  # scope :newest, order("updated_at DESC")
  # TODO: Sequences and possibly activities will eventually belong to projects e.g. HAS, SFF

  def name
    # activities have names, so to be consistent ...
    self.title
  end
  def time_to_complete
    time = 0
    lightweight_activities.map { |a| time = time + (a.time_to_complete ? a.time_to_complete : 0) }
    time
  end

  def activities
    lightweight_activities
  end

  def next_activity(activity)
    # Given an activity, return the next one in the sequence
    get_neighbor(activity, false)
  end

  def previous_activity(activity)
    # Given an activity, return the previous one in the sequence
    get_neighbor(activity, true)
  end

  def to_hash
    # We're intentionally not copying:
    # - is_official (defaults to false, can be changed)
    # - user_id (the copying user should be the owner)
    {
      title: title,
      description: description,
      publication_status: publication_status,
      abstract: abstract,
      theme_id: theme_id,
      project_id: project_id,
      logo: logo,
      display_title: display_title,
      thumbnail_url: thumbnail_url,
      external_report_url: external_report_url
    }
  end

  def fix_activity_position(positions)
    # This is not necessary, as 'lightweight_activities_sequences' is ordered by
    # position, so we already copied and add activities in a right order. However
    # copying exact position values seems to be safer and more resistant
    # to possible errors in the future.
    self.lightweight_activities_sequences.each_with_index do |sa, i|
      sa.position = positions[i]
      sa.save!
    end
    self.save!
  end

  def duplicate(new_owner)
    interactives_cache = InteractivesCache.new
    new_sequence = Sequence.new(self.to_hash)
    Sequence.transaction do
      new_sequence.title = "Copy of #{self.name}"
      new_sequence.user = new_owner
      positions = []
      lightweight_activities_sequences.each do |sa|
        new_a = sa.lightweight_activity.duplicate(new_owner, interactives_cache)
        new_a.name = new_a.name.sub('Copy of ', '')
        new_a.save!
        new_sequence.activities << new_a
        positions << sa.position
      end
      new_sequence.save!
      new_sequence.fix_activity_position(positions)
    end
    return new_sequence
  end

  def export
    sequence_json = self.as_json(only: [:title,
                                        :description,
                                        :abstract,
                                        :theme_id,
                                        :project_id,
                                        :logo,
                                        :display_title,
                                        :thumbnail_url,
                                        :external_report_url
    ])
    sequence_json[:activities] = []
    self.lightweight_activities.each_with_index do |a,i|
      activity_hash = a.export
      activity_hash[:position] = i+1
      sequence_json[:activities] << activity_hash
    end
    sequence_json[:type] = "Sequence"
    sequence_json[:export_site] = "Lightweight Activities Runtime and Authoring"
    return sequence_json.to_json
  end

  def serialize_for_portal(host)
    local_url = "#{host}#{Rails.application.routes.url_helpers.sequence_path(self)}"
    author_url = "#{local_url}/edit"
    print_url = "#{local_url}/print_blank"

    data = {
      'source_type' => 'LARA',
      'type' => 'Sequence',
      'name' => self.title,
      # Description is not used by new Portal anymore. However, we still need to send it to support older Portal instances.
      # Otherwise, the old Portal code would reset its description copy each time the sequence was published.
      # When all Portals are upgraded to v1.31 we can stop sending this property.
      'description' => self.description,
      # Abstract is not used by new Portal anymore. However, we still need to send it to support older Portal instances.
      # Otherwise, the old Portal code would reset its abstract copy each time the sequence was published.
      # When all Portals are upgraded to v1.31 we can stop sending this property.
      'abstract' => self.abstract,
      "url" => local_url,
      "create_url" => local_url,
      "author_url" => author_url,
      "print_url"  => print_url,
      "external_report_url" => external_report_url,
      "thumbnail_url" => thumbnail_url,
      "author_email" => self.user.email
    }
    data['activities'] = self.activities.map { |a| a.serialize_for_portal(host) }
    data
  end

  def self.extact_from_hash(sequence_json_object)
    {
      abstract: sequence_json_object[:abstract],
      description: sequence_json_object[:description],
      display_title: sequence_json_object[:display_title],
      logo: sequence_json_object[:logo],
      project_id: sequence_json_object[:project_id],
      theme_id: sequence_json_object[:theme_id],
      thumbnail_url: sequence_json_object[:thumbnail_url],
      title: sequence_json_object[:title],
      external_report_url: sequence_json_object[:external_report_url]
    }

  end

  def self.import(sequence_json_object, new_owner, imported_activity_url=nil)
    interactives_cache = InteractivesCache.new
    import_sequence = Sequence.new(self.extact_from_hash(sequence_json_object))
    Sequence.transaction do
      import_sequence.title = import_sequence.title
      import_sequence.imported_activity_url = imported_activity_url
      import_sequence.user = new_owner
      positions = []
      sequence_json_object[:activities].each do |sa|
        import_a = LightweightActivity.import(sa, new_owner, nil, interactives_cache)
        import_a.save!
        import_sequence.activities << import_a
        positions << sa[:position]
      end
      import_sequence.save!
      import_sequence.fix_activity_position(positions)
    end
    return import_sequence
  end

  def self.search(query)
    where("title LIKE ?", "%#{query}%")
  end

  private
  def get_neighbor(activity, higher)
    join = lightweight_activities_sequences.find_by_lightweight_activity_id(activity.id)
    if join.blank? || (join.first? && higher) || (join.last? && !higher)
      return nil
    elsif join && higher
      return join.higher_item.lightweight_activity
    elsif join && !higher
      return join.lower_item.lightweight_activity
    else
      return nil
    end
  end
end
