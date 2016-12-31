# encoding: utf-8
# TODO: move this into a new InfoController
class ObserverController
  # Intro to site.
  def intro # :nologin:
  end

  # Recent features.
  def news # :nologin:
  end

  # Help page.
  def how_to_use # :nologin:
    @min_pos_vote = Vote.confidence(Vote.min_pos_vote)
    @min_neg_vote = Vote.confidence(Vote.min_neg_vote)
    @maximum_vote = Vote.confidence(Vote.maximum_vote)
  end

  # A few ways in which users can help.
  def how_to_help # :nologin:
  end

  def wrapup_2011 # :nologin:
  end

  # Terminology description for RISD illustration class
  def risd_terminology # :nologin:
  end

  # Simple form letting us test our implementation of Textile.
  def textile_sandbox # :nologin:
    if request.method != "POST"
      @code = nil
    else
      @code = params[:code]
      @submit = params[:commit]
    end
    render(action: :textile_sandbox)
  end

  # I keep forgetting the stupid "_sandbox" thing.
  alias_method :textile, :textile_sandbox # :nologin:

  # Allow translator to enter a special note linked to from the lower left.
  def translators_note # :nologin:
  end
end
