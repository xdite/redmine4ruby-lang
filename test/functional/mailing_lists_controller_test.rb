require File.dirname(__FILE__) + '/../test_helper'

# Re-raise errors caught by the controller.
class MailingListController; def rescue_action(e) raise e end; end

class MailingListsControllerTest < Test::Unit::TestCase
  fixtures :users, :mailing_lists

  def setup
    @controller = MailingListsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def test_should_get_index
    get :index
    assert_response :success
    assert_not_nil assigns(:mailing_lists)
  end

  def test_should_get_add
    get :add
    assert_response :success
  end

  def test_should_create_mailing_list
    assert_difference('MailingList.count') do
      post :add, :mailing_list => { :name => 'created by test', :address => 'test@example.com', :locale => 'ja' }
    end

    assert_redirected_to :controller => 'mailing_lists'
  end

  def test_should_get_edit
    get :edit, :id => mailing_lists(:ruby_dev).id
    assert_response :success
  end

  def test_should_update_mailing_list
    post :edit, :id => mailing_lists(:ruby_dev).id, :mailing_list => { :name => 'modified by test' }
    assert_not_nil assigns(:mailing_list)
    assert_redirected_to :controller => 'mailing_lists', :id => assigns(:mailing_list).id, :action => 'edit'
  end

  def test_should_destroy_mailing_list
    assert_difference('MailingList.count', -1) do
      post :destroy, :id => mailing_lists(:ruby_dev).id
    end

    assert_redirected_to :controller => 'mailing_lists'
  end
end
