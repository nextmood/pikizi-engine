require 'test_helper'

class KnowledgesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:knowledges)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create knowledge" do
    assert_difference('Knowledge.count') do
      post :create, :knowledge => { }
    end

    assert_redirected_to knowledge_path(assigns(:knowledge))
  end

  test "should show knowledge" do
    get :show, :id => knowledges(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => knowledges(:one).to_param
    assert_response :success
  end

  test "should update knowledge" do
    put :update, :id => knowledges(:one).to_param, :knowledge => { }
    assert_redirected_to knowledge_path(assigns(:knowledge))
  end

  test "should destroy knowledge" do
    assert_difference('Knowledge.count', -1) do
      delete :destroy, :id => knowledges(:one).to_param
    end

    assert_redirected_to knowledges_path
  end
end
