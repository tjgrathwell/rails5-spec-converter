# Rails5::SpecConverter

[![Build Status](https://travis-ci.org/tjgrathwell/rails5-spec-converter.svg?branch=master)](https://travis-ci.org/tjgrathwell/rails5-spec-converter)

A script that fixes the syntax of your tests so Rails 5 will like them better. Inspired by [transpec](https://github.com/yujinakayama/transpec), the RSpec 2 -> 3 syntax conversion tool.

If you write a test like this:

```
get :users, search: 'bayleef', format: :json
expect(response).to be_success
```

Rails 5 will issue a hearty deprecation warning, persuading you to write this instead:

```
get :users, params: { search: 'bayleef' }, format: :json
expect(response).to be_success
```

This is great! That syntax is great. However, if you have a thousand tests lying around, it will probably be very time consuming to find all the places where you need to fix that.

## Installation

Install the gem standalone like so:

    $ gem install rails5-spec-converter

## Usage

Make sure you've committed everything to Git first, then

    $ cd some-project
    $ rails5-spec-converter

This will update all the files in that directory matching the glob `spec/**/*_spec.rb`. It should be idempotent.

If you want to specify a specific set of files instead, you can run `rails5-spec-converter path_to_my_files`.

By default it will make some noise, run with `rails5-spec-converter --quiet` if you want it not to.

### Whitespace

#### Indentation

The tool will attempt to indent the newly-added "params" hash in situations when the arguments are on newlines, e.g.:

```
  get :index
      search: 'bayleef',
      format: :json
```

becomes

```
  get :index
      params: {
        search: 'bayleef'
      },
      format: :json
```

Since the extra spaces in front of 'params' are brand-new whitespace, you may want to configure them (default is 2 spaces).

`rails5-spec-converter --indent '    '`

`rails5-spec-converter --indent '\t'`

#### Hash Spacing

By default, for single-line hashes, a single space will be added after the opening curly brace and before the ending curly brace. The space will be omitted if the new params hash will contain any hash literals that do not have surrounding whitespace, ex:

```
post :users, user: {name: 'bayleef'}
```

becomes

```
post :users, params: {user: {name: 'bayleef'}}
```

To force hashes to be written without extra whitespace in all files regardless of context, use the argument `--no-hash-spacing`.

To force hashes to be written WITH extra whitespace in all files regardless of context, use the argument `--hash-spacing`.

## Limitations

`rails5-spec-converter` wants to partition your arguments into two sets, those that belong in `params` and those that don't.

But it doesn't do any runtime analysis, so it can only effectively sort out non-`params` keys if they're included in a hash literal on the test invocation site. Hence:

```
all_the_params = {
  search: 'bayleef',
  format: :json
}

get :users, all_the_params
```

will become

```
get :users, params: all_the_params
```

even though `format` should be **outside** the params hash.

#### Future Work

In cases where the hash keys are unknowable at parse time, future versions may optionally attempt to produce this sort of result:

```
all_the_params = {
  search: 'bayleef',
  format: :json
}

r5sc_user_params, r5sc_other_params = all_the_params.partition { |k,v| %i{session flash method body xhr format}.include?(k) }.map { |a| Hash[a] }
get :users, r5sc_other_params.merge(params: r5sc_user_params)
```

...which should allow your tests to pass without deprecation warnings while introducing an enticing code cleanup oppurtunity.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tjgrathwell/rails5-spec-converter. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

