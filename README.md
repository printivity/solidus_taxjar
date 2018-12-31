# SuperGood::SolidusTaxJar

SuperGood::SolidusTaxJar is a [Solidus](https://github.com/solidusio/solidus) extension that allows Solidus stores to use [TaxJar](https://www.taxjar.com/) for tax calculations.

This is not a fork of [spree_taxjar](https://github.com/vinsol-spree-contrib/spree_taxjar), like [solidus_taxjar](https://github.com/boomerdigital/solidus_taxjar). Instead, SuperGood::SolidusTaxJar uses the new configurable tax system [introduced by @adammathys](https://github.com/solidusio/solidus/pull/1892) in Solidus 2.4.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'super_good-solidus_taxjar'
```

And then execute:

    $ bundle

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/SuperGoodSoft/solidus_taxjar. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SuperGood::SolidusTaxjar project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/SuperGoodSoft/solidus_taxjar/blob/master/CODE_OF_CONDUCT.md).