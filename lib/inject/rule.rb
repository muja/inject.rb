class Inject::Rule
  attr_reader :key, :identifier, :value, :options

  def initialize(key, identifier, value, **options)
    @key = key
    @identifier = identifier
    @value = value
    @options = options
  end

  def <=>(other)
    # this one has before: :all or before: other
    [other.identifier, :all].include?(self.options[:before]) ||
      # other one has after: :all, or after: self
      [self.identifier, :all].include?(other.options[:after])
  end
end
