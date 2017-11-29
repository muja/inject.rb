# Inject

Inspired by angular's injection capabilities, this library provides some dependency injection
via the `injector` module. 

## Installation

Add this line to your application's Gemfile:

    gem 'dinject'

And then execute:

    $ bundle

Or install it yourself with:

    $ gem install dinject

## Usage

Install the gem, then use it like this:

```ruby
require 'dinject'

# Create injector
injector = Injector.new

# same as injector.insert(:epoch, :setter, Time.now, before: :all)
injector.epoch = Time.now

# Add a rule for `ip_address` that queries ipecho.net if potential other methods fail
# The `after: :all` ensures that this is run last if all other rules fail to inject a non-nil value
injector.insert(:ip_address, :ipecho, -> { require 'open-uri'; open("http://ipecho.net/plain").read }, after: :all)

# Add another rule for `ip_address`.
# We name this rule "ifconfig" as it calls that UNIX command to retrieve network information
# from the system. We assume a call to `ifconfig` is faster than an HTTP request, so we prioritize
# this over the :ipecho method. Note that the `before: :ipecho` here is redundant and could be
# omitted since `ipecho` already specifies to be considered last.
injector.insert(:ip_address, :ifconfig, -> { extract_ip_address(`ifconfig`) }, before: :ipecho)

# We may also use a gem that does the job for us - presumably, it uses some native syscalls
# and is the fastest method, so we give it the highest priority.
injector.insert(:ip_address, :some_gem, -> { require 'some_gem'; SomeGem.ip_address }, before: :all)

# Use the variables. The arguments will be injected by name.
# If any of the arguments associates with a non-existing rule,
# a RuleNotFound error will be raised.
# Optional arguments (as in `|x, y = 42|`) have the same effect.
# For optional arguments, you must use the key arguments (`|x, y: 42|`) introduced in Ruby 2.0
# Note that rules will inject those, even with `nil`.
injector.inject do |ip_address, epoch|
  puts "ip: #{ip_address}, epoch: #{epoch}"
end
```

The injector works with a priority queue, so in the above example, it will try to retrieve 
the ip_address *lazily* using `some_gem`. If `SomeGem.ip_address` returned `nil`, the next
rule `ifconfig` will be used and if that returns nil, a call to `ipecho.net` will be made via the
`ipecho` rule. If all rules return `nil`, `nil` is returned. If no rules exist,
`RuleNotFound` will be raised (or `NoMethodError` if called directly via e.g. `injector.ip_address`).

Once a value is injected, it will be used for any consecutive calls (it will not be injected again).

You can also define dependencies for rules. For a real world example,
let's say you need an authentication token to make API calls to a web service,
and you want to store this token locally for future invocations of your program.
What you'd do naturally is look in the local file whether the token is already there,
and if not, check for the environment variable SOME_WEB_SERVICE_TOKEN (or e.g. the CLI parameter),
and if that's empty, invoke a login to said web service using the user credentials for which we
have established multiple rules as well. Let's see it in action:

```ruby
# injector that already has rules/values for "token_file" and "cli_params" 

injector.insert(:token, :file, -> (token_file) do
  extract_token_from(token_file.read)
end, before: :all)

injector.insert(:token, :cli, -> (cli_params) do
  cli_params[:web_service_token]
end, after: :file)

injector.insert(:token, :env, -> do
  ENV["SOME_WEB_SERVICE_TOKEN"]
end, after: :cli)

injector.insert(:token, :login, -> (username, password) do
  SomeWebService.login(username, password).token
end, after: :all)

injector.insert(:username, :cli_params -> (cli_params) do
  cli_params[:username]
end, before: :all)

injector.insert(:username, :prompt, -> do
  $stdout.print "(someweb.service) Username: "
  $stdin.gets.chomp
end, after: :all)

injector.insert(:password, :cli_params -> (cli_params) do
  cli_params[:password]
end, before: :all)

injector.insert(:password, :prompt, -> do
  require 'io/console'
  begin
    $stdout.print "(someweb.service) Password: "
    $stdin.noecho(&:gets).chomp
  ensure puts
  end
end, after: :all)
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
