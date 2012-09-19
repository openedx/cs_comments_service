require './spec_helper'

describe "Discussion", :type => :request do

  subject { page }
  let(:thread_data){ {body: Faker::Lorem.paragraph(2), title: Faker::Lorem.sentence(5), topic: "General"} }

  steps "Discussion Forum View" do

    it "should let you log in" do
      log_in
      goto_course "BerkeleyX/CS188/fa12"
      click_link "Discussion" 
    end

    it "should have a list of threads" do
      expect { page.has_selector ".discussion-body .sidebar" }
    end

    it "should have the new post form be hidden" do
      page.find('.new-post-article').should_not be_visible
    end

    it "should show and hide the new post form" do
      click_link 'New Post'
      page.find('.new-post-article').should be_visible
      click_link 'Cancel'
      wait_until { !page.find('.new-post-article').visible? }
      page.find('.new-post-article').should_not be_visible
    end

    it "should let you create a new post" do
      click_link 'New Post'
      new_post_container = page.find('.new-post-article')
      old_first_thread_title = page.find('.post-list .list-item:first .title').text
      new_post_container.should be_visible
      fill_in_wmd_body(new_post_container, thread_data[:body])
      new_post_container.find('.new-post-title').set(thread_data[:title])
      click_button "Add post"
      new_first_thread_list_item = page.find('.post-list .list-item:first')
      new_first_thread_list_item.should have_content (thread_data[:title])
      new_first_thread_list_item.should_not have_content old_first_thread_title
    end

    it "should show the thread's body when a thread is clicked" do 
      page.find('.post-list .list-item:first').click
      page.find('.new-post-article').should_not be_visible
    end

  end

end
