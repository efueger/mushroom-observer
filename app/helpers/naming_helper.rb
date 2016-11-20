module NamingHelper
  def can_have_no_opinion(naming, vote)
    check_permission(naming) ? (!vote || vote.value == 0) : true
  end

  def naming_events(observation, details)
    events = observation.namings
    if details
      for naming in observation.namings
        events += naming.votes
      end
    end
    events.sort_by(&:created_at).reverse
  end

  def name_header(any_names)
    if any_names
      :show_namings_proposed_names.t
    else
      :show_namings_no_names_yet.t
    end
  end
end
