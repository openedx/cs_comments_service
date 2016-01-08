require 'faker'

# Reload i18n data for faker
I18n.reload!

FactoryGirl.define do
  factory :user do
    # Initialize the model with all attributes since we are using a custom _id field.
    # See https://github.com/thoughtbot/factory_girl/issues/544.
    initialize_with { new(attributes) }

    sequence(:username) { |n| "#{Faker::Internet.user_name}_#{n}" }
    sequence(:external_id) { username }
  end

  factory :comment_thread do
    title { Faker::Lorem.sentence }
    body { Faker::Lorem.paragraph }
    course_id { Faker::Lorem.word }
    thread_type :discussion
    commentable_id { Faker::Lorem.word }
    association :author, factory: :user
    group_id nil
    pinned false

    trait :subscribe_author do
      after(:create) do |thread|
        thread.author.subscribe(thread)
      end
    end

    trait :with_group_id do
      group_id { Faker::Number.number(4) }
    end
  end

  factory :comment do
    association :author, factory: :user
    comment_thread { parent ? parent.comment_thread : create(:comment_thread) }
    body { Faker::Lorem.paragraph }
    course_id { comment_thread.course_id }
    commentable_id { comment_thread.commentable_id }
    endorsed false
  end
end
