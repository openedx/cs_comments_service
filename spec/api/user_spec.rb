require 'spec_helper'

describe "app" do
  describe "users" do
    before :each do
      User.delete_all
      create_test_user 1
      create_test_user 2
    end
    describe "POST /api/v1/users" do
      it "creates a user" do
        post "/api/v1/users", id: "100", username: "user100", email: "user100@test.com"
        last_response.should be_ok
        user = User.find_by(external_id: "100")
        user.username.should == "user100"
        user.email.should == "user100@test.com"
      end
      it "returns error when id / username / email already exists" do
        post "/api/v1/users", id: "1", username: "user100", email: "user100@test.com"
        last_response.status.should == 400
        post "/api/v1/users", id: "100", username: "user1", email: "user100@test.com"
        last_response.status.should == 400
        post "/api/v1/users", id: "100", username: "user100", email: "user1@test.com"
        last_response.status.should == 400
      end
    end
    describe "PUT /api/v1/users/:user_id" do
      it "updates user information" do
        put "/api/v1/users/1", username: "new_user_1"
        last_response.should be_ok
        user = User.find_by("1")
        user.username.should == "new_user_1"
      end
      it "does not update id" do
        put "/api/v1/users/1", id: "100"
        last_response.should be_ok
        user = User.find_by("1")
        user.should_not be_nil
      end
      it "returns error if user does not exist" do
        put "/api/v1/users/100", id: "100"
        last_response.status.should == 400
      end
      it "returns error if new information has conflict with other users" do
        put "/api/v1/users/1", username: "user2"
        last_response.status.should == 400 
      end
    end
  end
end
