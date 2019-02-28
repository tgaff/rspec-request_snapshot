class Rspec::RequestSnapshot::Handlers::Text < Rspec::RequestSnapshot::Handlers::Base
  def compare(actual, expected)
    actual == expected
  end

  def comparable(str)
    transform(str)
  end

  def writable(str)
    str
  end

  private

  def transform(str)
    str = str.dup
    exclusions.each do |exclusion|
      str.gsub!(exclusion, '===EXCLUDED===')
    end
    str
  end

  def exclusions
    @exclusions ||= Array(@options[:excluding])
  end
end
