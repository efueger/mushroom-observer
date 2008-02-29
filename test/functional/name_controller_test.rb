require File.dirname(__FILE__) + '/../test_helper'
require 'name_controller'

# Re-raise errors caught by the controller.
class NameController; def rescue_action(e) raise e end; end

class NameControllerTest < Test::Unit::TestCase
  fixtures :names
  fixtures :users
  fixtures :namings
  fixtures :observations
  fixtures :locations
  fixtures :synonyms
  fixtures :past_names

  def setup
    @controller = NameController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_name_index
    get_with_dump :name_index
    assert_response :success
    assert_template 'name_index'
  end

  def test_observation_index
    get_with_dump :observation_index
    assert_response :success
    assert_template 'name_index'
  end

  def test_show_name
    get_with_dump :show_name, :id => 1
    assert_response :success
    assert_template 'show_name'
  end

  def test_show_past_name
    get_with_dump :show_past_name, :id => 1
    assert_response :success
    assert_template 'show_past_name'
  end

  def test_name_search
    @request.session[:pattern] = "56"
    get_with_dump :name_search
    assert_response :success
    assert_template 'name_index'
    assert_equal "Names matching '56'", @controller.instance_variable_get('@title')
    get_with_dump :name_search, { :page => 2 }
    assert_response :success
    assert_template 'name_index'
    assert_equal "Names matching '56'", @controller.instance_variable_get('@title')
  end

  def test_edit_name
    name = @coprinus_comatus
    params = { "id" => name.id.to_s }
    requires_login(:edit_name, params)
    assert_form_action :action => 'edit_name'
  end

  def test_bulk_name_edit_list
    requires_login :bulk_name_edit
    assert_form_action :action => 'bulk_name_edit'
  end

  def test_change_synonyms
    name = @chlorophyllum_rachodes
    params = { :id => name.id }
    requires_login(:change_synonyms, params)
    assert_form_action :action => 'change_synonyms', :approved_synonyms => ''
  end

  def test_deprecate_name
    name = @chlorophyllum_rachodes
    params = { :id => name.id }
    requires_login(:deprecate_name, params)
    assert_form_action :action => 'deprecate_name', :approved_name => ''
  end

  def test_approve_name
    name = @lactarius_alpigenes
    params = { :id => name.id }
    requires_login(:approve_name, params)
    assert_form_action :action => 'approve_name'
  end

  # ----------------------------
  #  Maps
  # ----------------------------

  # test_map - name with Observations that have Locations
  def test_map
    get_with_dump :map, :id => @agaricus_campestris.id
    assert_response :success
    assert_template 'map'
  end

  # test_map_no_loc - name with Observations that don't have Locations
  def test_map_no_loc
    get_with_dump :map, :id => @coprinus_comatus.id
    assert_response :success
    assert_template 'map'
  end

  # test_map_no_obs - name with no Observations
  def test_map_no_obs
    get_with_dump :map, :id => @conocybe_filaris.id
    assert_response :success
    assert_template 'map'
  end

  # ----------------------------
  #  Edit name.
  # ----------------------------

  def test_update_name
    name = @conocybe_filaris
    assert(name.text_name == "Conocybe filaris")
    assert(name.author.nil?)
    past_names = name.past_names.size
    assert(0 == name.version)
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => "(Fr.) Kühner",
        :rank => :Species,
        :citation => "__Le Genera Galera__, 139. 1935.",
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    name = Name.find(name.id)
    assert_equal("(Fr.) Kühner", name.author)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.display_name)
    assert_equal("**__Conocybe filaris__** (Fr.) Kühner", name.observation_name)
    assert_equal("Conocybe filaris (Fr.) Kühner", name.search_name)
    assert_equal("__Le Genera Galera__, 139. 1935.", name.citation)
    assert_equal(@rolf, name.user)
  end

  # Test name changes in various ways.
  def test_update_name_deprecated
    name = @lactarius_alpigenes
    assert(name.deprecated)
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => "",
        :rank => :Species,
        :citation => "",
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    name = Name.find(name.id)
    assert(name.deprecated)
  end

  def test_update_name_different_user
    name = @macrolepiota_rhacodes
    name_owner = name.user
    user = "rolf"
    assert(user != name_owner.login) # Make sure it's not owned by the default user
    params = {
      :id => name.id,
      :name => {
        :text_name => name.text_name,
        :author => name.author,
        :rank => :Species,
        :citation => name.citation,
        :notes => name.notes
      }
    }
    post_requires_login(:edit_name, params, false, user)
    assert_redirected_to(:controller => "name", :action => "show_name")
    name = Name.find(name.id)
    assert(name_owner == name.user)
  end

  def test_update_name_simple_merge
    misspelt_name = @agaricus_campestrus
    correct_name = @agaricus_campestris
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(2, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => @agaricus_campestris.text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.past_names.size)

    assert_equal(3, correct_name.namings.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestris, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestris, correct_obs.name)
  end

  def test_update_name_author_merge
    misspelt_name = @amanita_baccata_borealis
    correct_name = @amanita_baccata_arora
    assert_not_equal(misspelt_name, correct_name)
    assert_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.past_names.size
    assert_equal(0, correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => misspelt_name.text_name,
        :author => correct_name.author,
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert_equal(correct_author, correct_name.author)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.past_names.size)
  end

  # Test that merged names end up as not deprecated if the
  # correct name is not deprecated.
  def test_update_name_deprecated_merge
    misspelt_name = @lactarius_alpigenes
    assert(misspelt_name.deprecated)
    correct_name = @lactarius_alpinus
    assert(!correct_name.deprecated)
    assert_not_equal(misspelt_name, correct_name)
    assert_not_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.past_names.size
    assert_equal(0, correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_name.text_name,
        :author => correct_name.author,
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(!correct_name.deprecated)
    assert_equal(correct_author, correct_name.author)
    assert_equal(0, correct_name.version)
    assert_equal(past_names, correct_name.past_names.size)
  end

  # Test that merged names end up as not deprecated even if the
  # correct name is deprecated but the misspelt name is not deprecated
  def test_update_name_deprecated2_merge
    misspelt_name = @lactarius_alpinus
    assert(!misspelt_name.deprecated)
    correct_name = @lactarius_alpigenes
    assert(correct_name.deprecated)
    assert_not_equal(misspelt_name, correct_name)
    assert_not_equal(misspelt_name.text_name, correct_name.text_name)
    correct_author = correct_name.author
    correct_text_name = correct_name.text_name
    assert_not_equal(misspelt_name.author, correct_author)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_name.text_name,
        :author => correct_name.author,
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      correct_name = Name.find(correct_name.id)
    end
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    assert(!misspelt_name.deprecated)
    assert_equal(correct_author, misspelt_name.author)
    assert_equal(correct_text_name, misspelt_name.text_name)
    assert(1 == misspelt_name.version)
    assert(past_names+1 == misspelt_name.past_names.size)
  end

  def test_update_name_page_unmergeable
    misspelt_name = @agaricus_campestras
    correct_name = @agaricus_campestris
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(2, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    # Because misspelt name is unmergable it gets reused and
    # corrected rather than the correct name
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(correct_name.id)
    end
    correct_name = Name.find(misspelt_name.id)
    assert(correct_name)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.past_names.size)

    assert_equal(3, correct_name.namings.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestras, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestras, correct_obs.name)
  end

  def test_update_name_other_unmergeable
    misspelt_name = @agaricus_campestrus
    correct_name = @agaricus_campestras
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(1, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      misspelt_name = Name.find(misspelt_name.id)
    end
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(1 == correct_name.version)
    assert(past_names+1 == correct_name.past_names.size)

    assert_equal(2, correct_name.namings.size)
    misspelt_obs = Observation.find(misspelt_obs_id)
    assert_equal(@agaricus_campestras, misspelt_obs.name)
    correct_obs = Observation.find(correct_obs_id)
    assert_equal(@agaricus_campestras, correct_obs.name)
  end

  def test_update_name_neither_mergeable
    misspelt_name = @agaricus_campestros
    correct_name = @agaricus_campestras
    correct_text_name = correct_name.text_name
    correct_author = correct_name.author
    assert_not_equal(misspelt_name, correct_name)
    past_names = correct_name.past_names.size
    assert(0 == correct_name.version)
    assert_equal(1, misspelt_name.namings.size)
    misspelt_obs_id = misspelt_name.namings[0].observation.id
    assert_equal(1, correct_name.namings.size)
    correct_obs_id = correct_name.namings[0].observation.id

    params = {
      :id => misspelt_name.id,
      :name => {
        :text_name => correct_text_name,
        :author => "",
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_response :success
    assert_template 'edit_name'
    misspelt_name = Name.find(misspelt_name.id)
    assert(misspelt_name)
    correct_name = Name.find(correct_name.id)
    assert(correct_name)
    assert(0 == correct_name.version)
    assert(past_names == correct_name.past_names.size)
    assert_equal(1, correct_name.namings.size)
    assert_equal(1, misspelt_name.namings.size)
    assert_not_equal(correct_name.namings[0], misspelt_name.namings[0])
  end

  def test_update_name_page_version_merge
    page_name = @coprinellus_micaceus
    other_name = @coprinellus_micaceus_no_author
    assert(page_name.version > other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    correct_author = page_name.author
    assert_not_equal(other_name.author, correct_author)
    past_names = page_name.past_names.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(other_name.id)
    end
    merge_name = Name.find(page_name.id)
    assert(merge_name)
    assert_equal(correct_author, merge_name.author)
    assert_equal(past_names, merge_name.version)
  end

  def test_update_name_other_version_merge
    page_name = @coprinellus_micaceus_no_author
    other_name = @coprinellus_micaceus
    assert(page_name.version < other_name.version)
    assert_not_equal(page_name, other_name)
    assert_equal(page_name.text_name, other_name.text_name)
    correct_author = other_name.author
    assert_not_equal(page_name.author, correct_author)
    past_names = other_name.past_names.size
    params = {
      :id => page_name.id,
      :name => {
        :text_name => page_name.text_name,
        :author => '',
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    assert_raises(ActiveRecord::RecordNotFound) do
      destroyed_name = Name.find(page_name.id)
    end
    merge_name = Name.find(other_name.id)
    assert(merge_name)
    assert_equal(correct_author, merge_name.author)
    assert_equal(past_names, merge_name.version)
  end

  def test_update_name_add_author
    name = @strobilurus_diminutivus_no_author
    old_text_name = name.text_name
    new_author = 'Desjardin'
    assert(name.namings.length > 0)
    params = {
      :id => name.id,
      :name => {
        :author => new_author,
        :rank => :Species,
        :notes => ""
      }
    }
    post_requires_login(:edit_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    name = Name.find(name.id)
    assert_equal(new_author, name.author)
    assert_equal(old_text_name, name.text_name)
  end

  # ----------------------------
  #  Bulk names.
  # ----------------------------

  def test_update_bulk_names_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_response :success
    assert_template 'bulk_name_edit'
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
  end

  def test_update_bulk_names_approved_nn_synonym
    new_name_str = "Amanita fergusonii"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_name_str]))
    new_synonym_str = "Amanita lanei"
    assert_nil(Name.find(:first, :conditions => ["text_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{new_name_str} = #{new_synonym_str}"},
      :approved_names => [new_name_str, new_synonym_str]
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    new_name = Name.find(:first, :conditions => ["text_name = ?", new_name_str])
    assert(new_name)
    assert_equal(new_name_str, new_name.text_name)
    assert_equal("**__#{new_name_str}__**", new_name.display_name)
    assert(!new_name.deprecated)
    assert_equal(:Species, new_name.rank)
    synonym_name = Name.find(:first, :conditions => ["text_name = ?", new_synonym_str])
    assert(synonym_name)
    assert_equal(new_synonym_str, synonym_name.text_name)
    assert_equal("__#{new_synonym_str}__", synonym_name.display_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(new_name.synonym)
    assert_equal(new_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_ee_synonym
    approved_name = @chlorophyllum_rachodes
    synonym_name = @macrolepiota_rachodes
    assert_not_equal(approved_name.synonym, synonym_name.synonym)
    assert(!synonym_name.deprecated)
    params = {
      :list => { :members => "#{approved_name.search_name} = #{synonym_name.search_name}"},
    }
    post_requires_login(:bulk_name_edit, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(approved_name.id)
    assert(!approved_name.deprecated)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
  end

  def test_update_bulk_names_eee_synonym
    approved_name = @lepiota_rachodes
    synonym_name = @lepiota_rhacodes
    assert_nil(approved_name.synonym)
    assert_nil(synonym_name.synonym)
    assert(!synonym_name.deprecated)
    synonym_name2 = @chlorophyllum_rachodes
    assert_not_nil(synonym_name2.synonym)
    assert(!synonym_name2.deprecated)
    params = {
      :list => { :members => ("#{approved_name.search_name} = #{synonym_name.search_name}\r\n" +
                              "#{approved_name.search_name} = #{synonym_name2.search_name}")},
    }
    post_requires_login(:bulk_name_edit, params, false)
    # print "\n#{flash[:notice]}\n"
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(approved_name.id)
    assert(!approved_name.deprecated)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    synonym_name2 = Name.find(synonym_name2.id)
    assert(synonym_name.deprecated)
    assert_equal(approved_name.synonym, synonym_name2.synonym)
  end

  def test_update_bulk_names_en_synonym
    approved_name = @chlorophyllum_rachodes
    target_synonym = approved_name.synonym
    assert(target_synonym)
    new_synonym_str = "New name Wilson"
    assert_nil(Name.find(:first, :conditions => ["search_name = ?", new_synonym_str]))
    params = {
      :list => { :members => "#{approved_name.search_name} = #{new_synonym_str}"},
      :approved_names => [approved_name.search_name, new_synonym_str]
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(approved_name.id)
    assert(!approved_name.deprecated)
    synonym_name = Name.find(:first, :conditions => ["search_name = ?", new_synonym_str])
    assert(synonym_name)
    assert(synonym_name.deprecated)
    assert_equal(:Species, synonym_name.rank)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, approved_name.synonym)
  end

  def test_update_bulk_names_ne_synonym
    new_name_str = "New name Wilson"
    assert_nil(Name.find(:first, :conditions => ["search_name = ?", new_name_str]))
    synonym_name = @macrolepiota_rachodes
    assert(!synonym_name.deprecated)
    target_synonym = synonym_name.synonym
    assert(target_synonym)
    params = {
      :list => { :members => "#{new_name_str} = #{synonym_name.search_name}"},
      :approved_names => [new_name_str, synonym_name.search_name]
    }
    post_requires_login(:bulk_name_edit, params, false)
    assert_redirected_to(:controller => "observer", :action => "list_rss_logs")
    approved_name = Name.find(:first, :conditions => ["search_name = ?", new_name_str])
    assert(approved_name)
    assert(!approved_name.deprecated)
    assert_equal(:Species, approved_name.rank)
    synonym_name = Name.find(synonym_name.id)
    assert(synonym_name.deprecated)
    assert_not_nil(approved_name.synonym)
    assert_equal(approved_name.synonym, synonym_name.synonym)
    assert_equal(target_synonym, approved_name.synonym)
  end

  # ----------------------------
  #  Synonyms.
  # ----------------------------

  # combine two Names that have no Synonym
  def test_transfer_synonyms_1_1
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    selected_past_name_count = selected_name.past_names.length
    selected_version = selected_name.version

    add_name = @lepiota_rhacodes
    assert(!add_name.deprecated)
    assert_equal("**__Lepiota rhacodes__** Vittad.", add_name.display_name)
    assert_nil(add_name.synonym)
    add_past_name_count = add_name.past_names.length
    add_name_version = add_name.version

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal("__Lepiota rhacodes__ Vittad.", add_name.display_name)
    assert_equal(add_past_name_count+1, add_name.past_names.length) # past name should have been created
    assert(!add_name.past_names[-1].deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_name_version+1, add_name.version)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_past_name_count, selected_name.past_names.length)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    assert(!Name.find(@lepiota.id).deprecated)
  end

  # combine two Names that have no Synonym and no deprecation
  def test_transfer_synonyms_1_1_nd
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    selected_version = selected_name.version

    add_name = @lepiota_rhacodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.text_name },
      :deprecate => { :all => "0" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_version, add_name.version)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)
  end

  # add new name string to Name with no Synonym but not approved
  def test_transfer_synonyms_1_0_na
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)
    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_response :success
    assert_template 'change_synonyms'

    selected_name = Name.find(selected_name.id)
    assert_nil(selected_name.synonym)
    assert(!selected_name.deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_0_a
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes" },
      :approved_names => ["Lepiota rachodes var. rachodes"],
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert_equal(selected_version, selected_name.version)
    synonym = selected_name.synonym
    assert_not_nil(synonym)
    assert_equal(2, synonym.names.length)
    for n in synonym.names
      if n == selected_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end
    assert(!Name.find(@lepiota.id).deprecated)
  end

  # add new name string to Name with no Synonym but approved
  def test_transfer_synonyms_1_00_a
    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => "Lepiota rachodes var. rachodes\r\nLepiota rhacodes var. rhacodes" },
      :approved_names => ["Lepiota rachodes var. rachodes", "Lepiota rhacodes var. rhacodes"],
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    synonym = selected_name.synonym
    assert_not_nil(synonym)
    assert_equal(3, synonym.names.length)
    for n in synonym.names
      if n == selected_name
        assert(!n.deprecated)
      else
        assert(n.deprecated)
      end
    end
    assert(!Name.find(@lepiota.id).deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym
  def test_transfer_synonyms_n_1
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_version+1, add_name.version)
    assert(!Name.find(@lepiota.id).deprecated)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates checked
  def test_transfer_synonyms_n_1_c
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    assert_nil(add_name.synonym)

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Check all names not matching the selected one
        assert(!n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "checked"
      end
    end
    assert_not_nil(split_name)
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(start_size + 1, add_synonym.names.size)

    split_name = Name.find(split_name.id)
    assert(!split_name.deprecated)
    split_synonym = split_name.synonym
    assert_equal(add_synonym, split_synonym)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name with no Synonym to a Name that has a Synonym wih the alternates not checked
  def test_transfer_synonyms_n_1_nc
    add_name = @lepiota_rachodes
    assert(!add_name.deprecated)
    assert_nil(add_name.synonym)
    add_version = add_name.version

    selected_name = @chlorophyllum_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Uncheck all names not matching the selected one
        assert(!n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "0"
      end
    end
    assert_not_nil(split_name)
    assert(!split_name.deprecated)
    split_version = split_name.version
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
    assert_equal(2, add_synonym.names.size)

    split_name = Name.find(split_name.id)
    assert(!split_name.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with no approved synonyms
  def test_transfer_synonyms_1_n_ns
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_response :success
    assert_template 'change_synonyms'

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    assert_equal(add_version, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_nil(selected_synonym)

    assert_equal(start_size, add_synonym.names.size)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_s
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    synonym_ids = (add_synonym.names.map {|n| n.id}).join('/')
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :approved_synonyms => synonym_ids,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # add a Name that has a Synonym to a Name with no Synonym with all approved synonyms
  def test_transfer_synonyms_1_n_l
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    start_size = add_synonym.names.size

    selected_name = @lepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    assert_nil(selected_name.synonym)

    synonym_names = (add_synonym.names.map {|n| n.search_name}).join("\r\n")
    params = {
      :id => selected_name.id,
      :synonym => { :members => synonym_names },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")

    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)

    assert_equal(start_size+1, add_synonym.names.size)
    assert(!Name.find(@lepiota.id).deprecated)
    assert(!Name.find(@chlorophyllum.id).deprecated)
  end

  # combine two Names that each have Synonyms with no chosen names
  def test_transfer_synonyms_n_n_ns
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_response :success
    assert_template 'change_synonyms'

    add_name = Name.find(add_name.id)
    assert(!add_name.deprecated)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size, add_synonym.names.size)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_not_equal(add_synonym, selected_synonym)
    assert_equal(selected_start_size, selected_synonym.names.size)
  end

  # combine two Names that each have Synonyms with all chosen names
  def test_transfer_synonyms_n_n_s
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    synonym_ids = (add_synonym.names.map {|n| n.id}).join('/')
    params = {
      :id => selected_name.id,
      :synonym => { :members => add_name.search_name },
      :approved_synonyms => synonym_ids,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # combine two Names that each have Synonyms with all names listed
  def test_transfer_synonyms_n_n_l
    add_name = @chlorophyllum_rachodes
    assert(!add_name.deprecated)
    add_version = add_name.version
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    add_start_size = add_synonym.names.size

    selected_name = @macrolepiota_rachodes
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size
    assert_not_equal(add_synonym, selected_synonym)

    synonym_names = (add_synonym.names.map {|n| n.search_name}).join("\r\n")
    params = {
      :id => selected_name.id,
      :synonym => { :members => synonym_names },
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    add_name = Name.find(add_name.id)
    assert(add_name.deprecated)
    assert_equal(add_version+1, add_name.version)
    add_synonym = add_name.synonym
    assert_not_nil(add_synonym)
    assert_equal(add_start_size + selected_start_size, add_synonym.names.size)

    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(add_synonym, selected_synonym)
  end

  # split off a single name from a name with multiple synonyms
  def test_transfer_synonyms_split_3_1
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n.id != selected_id
        assert(n.deprecated)
        if split_name.nil? # Find the first different name and uncheck it
          split_name = n
          existing_synonyms[n.id.to_s] = "0"
        else
          kept_name = n
          existing_synonyms[n.id.to_s] = "checked" # Check the rest
        end
      end
    end
    split_version = split_name.version
    kept_version = kept_name.version
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert_equal(selected_version, selected_name.version)
    assert(!selected_name.deprecated)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(selected_start_size - 1, selected_synonym.names.size)

    split_name = Name.find(split_name.id)
    assert(split_name.deprecated)
    assert_equal(split_version, split_name.version)
    assert_nil(split_name.synonym)

    assert(kept_name.deprecated)
    assert_equal(kept_version, kept_name.version)
  end

  # split 4 synonymized names into two sets of synonyms with two members each
  def test_transfer_synonyms_split_2_2
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_names = []
    count = 0
    for n in selected_synonym.names
      if n != selected_name
        assert(n.deprecated)
        if count < 2 # Uncheck two names
          split_names.push(n)
          existing_synonyms[n.id.to_s] = "0"
        else
          existing_synonyms[n.id.to_s] = "checked"
        end
        count += 1
      end
    end
    assert_equal(2, split_names.length)
    assert_not_equal(split_names[0], split_names[1])
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert(!selected_name.deprecated)
    assert_equal(selected_version, selected_name.version)
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    assert_equal(selected_start_size - 2, selected_synonym.names.size)

    split_names[0] = Name.find(split_names[0].id)
    assert(split_names[0].deprecated)
    split_synonym = split_names[0].synonym
    assert_not_nil(split_synonym)
    split_names[1] = Name.find(split_names[1].id)
    assert(split_names[1].deprecated)
    assert_not_equal(split_names[0], split_names[1])
    assert_equal(split_synonym, split_names[1].synonym)
    assert_equal(2, split_synonym.names.size)
  end

  # take four synonymized names and separate off one
  def test_transfer_synonyms_split_1_3
    selected_name = @lactarius_alpinus
    assert(!selected_name.deprecated)
    selected_version = selected_name.version
    selected_id = selected_name.id
    selected_synonym = selected_name.synonym
    assert_not_nil(selected_synonym)
    selected_start_size = selected_synonym.names.size

    existing_synonyms = {}
    split_name = nil
    for n in selected_synonym.names
      if n != selected_name # Uncheck all names not matching the selected one
        assert(n.deprecated)
        split_name = n
        existing_synonyms[n.id.to_s] = "0"
      end
    end
    assert_not_nil(split_name)
    split_version = split_name.version
    params = {
      :id => selected_name.id,
      :synonym => { :members => "" },
      :existing_synonyms => existing_synonyms,
      :deprecate => { :all => "checked" }
    }
    post_requires_login(:change_synonyms, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name")
    selected_name = Name.find(selected_name.id)
    assert_equal(selected_version, selected_name.version)
    assert(!selected_name.deprecated)
    assert_nil(selected_name.synonym)

    split_name = Name.find(split_name.id)
    assert(split_name.deprecated)
    assert_equal(split_version, split_name.version)
    split_synonym = split_name.synonym
    assert_not_nil(split_synonym)
    assert_equal(selected_start_size - 1, split_synonym.names.size)
  end

  # ----------------------------
  #  Deprecation.
  # ----------------------------

  # deprecate an existing unique name with another existing name
  def test_do_deprecation
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.past_names.length
    current_version = current_name.version
    current_notes = current_name.notes

    proposed_name = @chlorophyllum_rachodes
    assert(!proposed_name.deprecated)
    assert_not_nil(proposed_name.synonym)
    proposed_synonym_length = proposed_name.synonym.names.size
    proposed_past_name_count = proposed_name.past_names.length
    proposed_version = proposed_name.version
    proposed_notes = proposed_name.notes

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name.text_name },
      :comment => { :comment => "Don't like this name"}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    old_name = Name.find(current_name.id)
    assert(old_name.deprecated)
    assert_equal(current_past_name_count+1, old_name.past_names.length) # past name should have been created
    assert(!old_name.past_names[-1].deprecated)
    old_synonym = old_name.synonym
    assert_not_nil(old_synonym)
    assert_equal(current_version+1, old_name.version)
    assert_not_equal(current_notes, old_name.notes)

    new_name = Name.find(proposed_name.id)
    assert(!new_name.deprecated)
    assert_equal(proposed_past_name_count, new_name.past_names.length)
    new_synonym = new_name.synonym
    assert_not_nil(new_synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(proposed_synonym_length+1, new_synonym.names.size)
    assert_equal(proposed_version, new_name.version)
    assert_equal(proposed_notes, new_name.notes)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_ambiguous
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.past_names.length

    proposed_name = @amanita_baccata_arora # Ambiguous text name
    assert(!proposed_name.deprecated)
    assert_nil(proposed_name.synonym)
    proposed_past_name_count = proposed_name.past_names.length

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name.text_name },
      :comment => { :comment => ""}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_response :success # Fail since name can't be disambiguated
    assert_template 'deprecate_name'

    old_name = Name.find(current_name.id)
    assert(!old_name.deprecated)
    assert_equal(current_past_name_count, old_name.past_names.length)
    assert_nil(old_name.synonym)

    new_name = Name.find(proposed_name.id)
    assert(!new_name.deprecated)
    assert_equal(proposed_past_name_count, new_name.past_names.length)
    assert_nil(new_name.synonym)
  end

  # deprecate an existing unique name with an ambiguous name, but using :chosen_name to disambiguate
  def test_do_deprecation_chosen
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.past_names.length

    proposed_name = @amanita_baccata_arora # Ambiguous text name
    assert(!proposed_name.deprecated)
    assert_nil(proposed_name.synonym)
    proposed_synonym_length = 0
    proposed_past_name_count = proposed_name.past_names.length

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name.text_name },
      :chosen_name => { :name_id => proposed_name.id },
      :comment => { :comment => "Don't like this name"}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    old_name = Name.find(current_name.id)
    assert(old_name.deprecated)
    assert_equal(current_past_name_count+1, old_name.past_names.length) # past name should have been created
    assert(!old_name.past_names[-1].deprecated)
    old_synonym = old_name.synonym
    assert_not_nil(old_synonym)

    new_name = Name.find(proposed_name.id)
    assert(!new_name.deprecated)
    assert_equal(proposed_past_name_count, new_name.past_names.length)
    new_synonym = new_name.synonym
    assert_not_nil(new_synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  # deprecate an existing unique name with an ambiguous name
  def test_do_deprecation_new_name
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.past_names.length

    proposed_name_str = "New name"

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name_str },
      :comment => { :comment => "Don't like this name"}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_response :success # Fail since new name is not approved
    assert_template 'deprecate_name'

    old_name = Name.find(current_name.id)
    assert(!old_name.deprecated)
    assert_equal(current_past_name_count, old_name.past_names.length)
    assert_nil(old_name.synonym)
  end

  # deprecate an existing unique name with an ambiguous name, but using :chosen_name to disambiguate
  def test_do_deprecation_approved_new_name
    current_name = @lepiota_rachodes
    assert(!current_name.deprecated)
    assert_nil(current_name.synonym)
    current_past_name_count = current_name.past_names.length

    proposed_name_str = "New name"

    params = {
      :id => current_name.id,
      :proposed => { :name => proposed_name_str },
      :approved_name => proposed_name_str,
      :comment => { :comment => "Don't like this name"}
    }
    post_requires_login(:deprecate_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    old_name = Name.find(current_name.id)
    assert(old_name.deprecated)
    assert_equal(current_past_name_count+1, old_name.past_names.length) # past name should have been created
    assert(!old_name.past_names[-1].deprecated)
    old_synonym = old_name.synonym
    assert_not_nil(old_synonym)

    new_name = Name.find(:first, :conditions => ["text_name = ?", proposed_name_str])
    assert(!new_name.deprecated)
    new_synonym = new_name.synonym
    assert_not_nil(new_synonym)
    assert_equal(old_synonym, new_synonym)
    assert_equal(2, new_synonym.names.size)
  end

  # ----------------------------
  #  Approval.
  # ----------------------------

  # approve a deprecated name
  def test_do_approval_default
    current_name = @lactarius_alpigenes
    assert(current_name.deprecated)
    assert(current_name.synonym)
    current_past_name_count = current_name.past_names.length
    current_version = current_name.version
    approved_synonyms = current_name.approved_synonyms
    current_notes = current_name.notes

    params = {
      :id => current_name.id,
      :deprecate => { :others => '1' },
      :comment => { :comment => "Prefer this name"}
    }
    post_requires_login(:approve_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    current_name = Name.find(current_name.id)
    assert(!current_name.deprecated)
    assert_equal(current_past_name_count+1, current_name.past_names.length) # past name should have been created
    assert(current_name.past_names[-1].deprecated)
    assert_equal(current_version + 1, current_name.version)
    assert_not_equal(current_notes, current_name.notes)

    for n in approved_synonyms
      n = Name.find(n.id)
      assert(n.deprecated)
    end
  end

  # approve a deprecated name, but don't deprecate the synonyms
  def test_do_approval_no_deprecate
    current_name = @lactarius_alpigenes
    assert(current_name.deprecated)
    assert(current_name.synonym)
    current_past_name_count = current_name.past_names.length
    approved_synonyms = current_name.approved_synonyms

    params = {
      :id => current_name.id,
      :deprecate => { :others => '0' },
      :comment => { :comment => ""}
    }
    post_requires_login(:approve_name, params, false)
    assert_redirected_to(:controller => "name", :action => "show_name") # Success

    current_name = Name.find(current_name.id)
    assert(!current_name.deprecated)
    assert_equal(current_past_name_count+1, current_name.past_names.length) # past name should have been created
    assert(current_name.past_names[-1].deprecated)

    for n in approved_synonyms
      n = Name.find(n.id)
      assert(!n.deprecated)
    end
  end
end