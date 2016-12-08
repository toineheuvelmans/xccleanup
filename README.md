# xccleanup

A cleanup tool that assists you in cleaning up after Xcode.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'xccleanup'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install xccleanup

## Usage

Just run it. You'll be asked which steps you would like to run. Available steps:

1. Remove derived data
2. Remove module cache
3. Remove device support
4. Remove old archives
5. Remove expired provisioning profiles
6. Remove simulator devices
7. Remove doc sets

## Backlog

To be added in the (near future):

* Remove device support for tvOS and watchOS (currenty only iOS is checked).
* Provide different modes for specifying OS versions to keep.
* Remove expired or revoked certificates and (non-Apple) certificates without private key. (is that possible, is that wise?)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/toineheuvelmans/xccleanup.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

