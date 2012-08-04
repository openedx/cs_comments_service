class Content
  include Mongoid::Document
  
  AT_NOTIFICATION_REGEX = /(?<=^|\s)(@[A-Za-z0-9_]+)(?!\w)/
  
  def self.get_marked_text(text)
    counter = -1
    text.gsub AT_NOTIFICATION_REGEX do
      counter += 1
      "#{$1}_#{counter}"
    end
  end

  def self.get_at_position_list(text)
    list = []
    text.gsub AT_NOTIFICATION_REGEX do
      parts = $1.rpartition('_')
      list << [parts.last.to_i, parts.first[1..-1]]
    end
    list
  end

  def self.get_valid_at_position_list(text)
    html = Nokogiri::HTML(RDiscount.new(self.get_marked_text(text)).to_html)
    html.xpath('//code').each do |c|
      c.children = ''
    end
    self.get_at_position_list html.to_s
  end

end
