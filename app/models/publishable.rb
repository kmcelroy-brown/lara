module Publishable
  def find_portal_publication(concord_auth_portal)
    self.portal_publications.where('portal_url' =>  concord_auth_portal.publishing_url).last
  end
  alias_method :last_publication, :find_portal_publication
  def portal_publish(user,auth_portal,self_url)
    self.update_attribute('publication_status','public')
    self.portal_publish_with_token(user.authentication_token,auth_portal,self_url)
  end

  def republish_for_portal(auth_portal,self_url)
    portal_publish_with_token(auth_portal.secret,auth_portal,self_url,true)
  end

  def publication_details
    res = self.portal_publications.where(:success => true).group(:portal_url)
    counts = res.size
    return_vals = []
    dates  = res.maximum(:created_at)
    counts.keys.each do |url|
      obj = OpenStruct.new
      obj.url = url.gsub(/https?:\/\/([^\/]*).*/){ |x| $1 }
      obj.count = counts[url]
      obj.date  = dates[url].strftime('%F %R')
      return_vals << obj
    end
    return return_vals
  end

  def portal_publish_with_token(token,auth_portal,self_url,republish=false)
    # TODO: better error handling
    raise "#{self.class.name} is Not Publishable" unless self.respond_to?(:serialize_for_portal)
    url = auth_portal.publishing_url
    url = auth_portal.republishing_url if republish
    Rails.logger.info "Attempting to publish #{self.class.name} #{self.id} to #{auth_portal.url}."
    auth_token = 'Bearer %s' % token
    response = HTTParty.post(url,
      :body => self.serialize_for_portal(self_url).to_json,
      :headers => {"Authorization" => auth_token, "Content-Type" => 'application/json'})

    Rails.logger.info "Response: #{response.inspect}"
    self.portal_publications.create({
      portal_url: auth_portal.publishing_url,
      response: response.inspect,
      success: ( response.code == 201 ) ? true : false,
      publishable: self
    })

    return true if response.code == 201
    return false
  end

  def add_portal_publication(concord_auth_portal)
   found = find_portal_publication(concord_auth_portal)
   self.portal_publications.create(portal_url: concord_auth_portal.publishing_url) unless found
  end

  def remove_portal_publication(concord_auth_portal)
    found = find_portal_publication(concord_auth_portal)
    self.portal_publications.destroy(found) if found
  end

  def publish_to_portals(self_url)
    urls = self.portal_publications.where(:success => true).pluck(:portal_url).uniq
    urls.map { |url| Concord::AuthPortal.portal_for_publishing_url(url)}.each do |portal|
      self.republish_for_portal(portal,self_url)
    end
  end

  ## auto publishing methods

  def self.included(clazz)
    clazz.class_eval do
      after_update :auto_publish_to_portal
    end
  end

  def auto_publish_to_portal
    logger.debug "TODO: Autopublish #{self}"
  end
end
