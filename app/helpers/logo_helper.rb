module LogoHelper

  # TODO: This is weird, in this helper we assume @projec & @theme.

  def logo_tag(png="cc-logo.png",title="The Concord Consortium", url="http://concord.org/")
    id    = png.gsub("-logo","")
    img   = image_tag(png, :alt => title, :id => id)
    link_to(img, url, :title => title)
  end

  def project_logo_tag
    project = @project
    if project and project.logo.present?
      return logo_tag(project.logo, project.title, project.url)
    end
    return nil
  end

  def sequence_logo_tag
    sequence = @sequence
    return nil unless sequence
    logo = sequence.logo

    if @sequence_run
      url = sequence_path(:id => sequence.id, :show_index => true, :sequence_run => @sequence_run.id)
    else
      url = sequence_path(:id => sequence.id, :show_index => true)
    end
    buffer = ''.html_safe
    if logo.present?
      buffer << logo_tag(logo, sequence.display_title, url)
    end
    title  = @sequence.display_title.blank? ? @sequence.title : @sequence.display_title
    unless title.blank?
      link = content_tag(:a, title, :class => "sequence_title", :href=> url)
      buffer << content_tag(:h2, link)
    end
    return content_tag(:div, buffer, :class => "sequence_logo_block")
  end

  def concord_logo_tag
    logo_tag
  end

  def mw_logo_tag
    logo_tag("mw-logo.png","Molecular Workbench", "http://mw.concord.org/nextgen")
  end

  def left_logo_tag
    return sequence_logo_tag || project_logo_tag || nil
  end

  def right_logo_tag
    if sequence_logo_tag
      return project_logo_tag || concord_logo_tag
    end
    return concord_logo_tag
  end

end
