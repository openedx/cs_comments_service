def log_in
  visit "/"
  click_link "Log In"
  fill_in "password", with: "student"
  click_button "Access My Courses"
  wait_until { page.find('.dashboard') }
end

def goto_course(course)
  visit "/courses/#{course}/info"
end

def fill_in_wmd_body(container, body)
  container.find("textarea.wmd-input").set(body)
end
