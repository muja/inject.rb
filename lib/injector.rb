require 'pqueue'
require 'inject/rule'

class Injector
  class RuleNotFound < StandardError; end

  def initialize(**params)
    @rules = {}
    @injected = {injector: self}
    @callbacks = {}
    params.each do |k, v|
      set(k, v)
    end
  end

  def get(key, overrides = {})
    # (lazily) evaluate rule, then store it
    @injected[key] ||= begin
      arr = @rules[key]
      if arr.nil?
        raise RuleNotFound,
          "No rule for #{key.inspect}. Available fields: #{@rules.keys.map(&:inspect).join(', ')}"
      end
      result = nil
      arr.to_a.reverse.each do |rule|
        rule.value.tap do |x|
          # if it's a callable value, call that and return its result, else return itself
          result = if x.is_a?(Proc) or x.is_a?(Method)
            inject(overrides, &x)
          else
            x
          end
        end
        unless result.nil?
          fire(:after_fetch, key, result, rule.identifier)
          break
        end
      end
      result
    end
  end

  def inject(overrides = {}, &block)
    params = []
    keys = {}
    block.parameters.each_with_index do |(type, value), index|
      raise(
        ArgumentError,
        [
          "splash operator arguments are not permitted when injecting.",
          ":#{value} in #{ block.source_location }"
        ].join(" ")
      ) if type == :rest or type == :keyrest

      # fetch by index first! e.g. inject(0 => 40) { |x| x + 2 }
      result = overrides.fetch(index) do
        # then fetch by value
        overrides.fetch(value) do
          # Unfortunately, optional arguments are not possible, as
          # a Ruby block passed to `inject` will have exclusively optional arguments.
          # Instead, key arguments introduced in Ruby 2.0 should be used.
          if type == :key
            begin self.get(value)
            rescue RuleNotFound
            end
          else
            self.get(value)
          end
        end
      end
      if type == :key
        keys[value] = result
      else
        params << result
      end
    end

    if keys.empty?
      block.call(*params)
    else
      block.call(*params, keys)
    end
  end

  def set(key, value)
    insert(key, :setter, value, before: :all)
  end

  alias :[]  :get
  alias :[]= :set

  def when_fetched(key = nil, &block)
    add_callback(:after_fetch, key, &block)
  end

  def insert(key, identifier = nil, block, **options)
    insert_rule(Inject::Rule.new(key, identifier, block, **options))
  end
  alias_method :provide, :insert

  def insert_rules(rules)
    rules.each(&method(:insert_rule))
  end

  def insert_rule(rule)
    (@rules[rule.key] ||= PQueue.new) << rule
    define_singleton_method(rule.key) { get(rule.key) }
  end

  def invalidate(key, identifier = :all)
    if queue = @rules[key]
      new_queue = case identifier
      when :all then []
      else
        queue.to_a.delete_if do |rule|
          rule.identifier == identifier
        end
      end
      queue.replace(new_queue)
      true
    end
  end

private
  def add_callback(event, key, &block)
    key ||= block.parameters.first.last
    ((@callbacks[event] ||= {})[key] ||= []) << block
  end

  def fire(event, key, value, identifier)
    @callbacks.fetch(event, {}).fetch(key, []).each do |block|
      inject(method: identifier, 0 => value, &block)
    end
  end

  def method_missing(method, *args)
    super unless method.to_s.end_with? "="
    self.set(method[0...-1].to_sym, *args)
  end
end
