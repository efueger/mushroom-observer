module NamingHelper
  def can_have_no_opinion(naming, vote)
    check_permission(naming) ? (!vote || vote.value == 0) : true
  end
end
