require 'spec_helper'

describe ThreadListPresenter do
  context "#initialize" do
    before(:each) do
      User.all.delete
      Content.all.delete
      @threads = (1..3).map do |n|
        t = make_thread(
          create_test_user("author#{n}"),
          "thread #{n}",
          'foo', 'bar'
        )
      end
      @reader = create_test_user('reader')
    end

    it "handles unread threads" do
      pres = ThreadListPresenter.new(@threads, @reader, 'foo')
      pres.to_hash.each_with_index do |h, i|
        h.should == ThreadPresenter.factory(@threads[i], @reader).to_hash
      end
    end

    it "handles read threads" do
      @reader.mark_as_read(@threads[0])
      @reader.save!
      pres = ThreadListPresenter.new(@threads, @reader, 'foo')
      pres.to_hash.each_with_index do |h, i|
        h.should == ThreadPresenter.factory(@threads[i], @reader).to_hash
      end
    end

    it "handles empty list of threads" do
      pres = ThreadListPresenter.new([], @reader, 'foo')
      pres.to_hash.should == []
    end

  end
end
