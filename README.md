# RdsAuroraConcerto

This gem provide feature which to clone Aurora instance.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rds_aurora_concerto'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rds_aurora_concerto

## Usage
### Config
Put yaml to project root as `.concert.yml`.

```yaml
aws:
  region: ap-northeast-1
  access_key_id: <%= '11111111' * 2 %>
  secret_access_key: <%= '44' * 2 %>
  account_id: 111111111
database_url_format: "mysql2://{db_user}:{db_password}@#%{db_endpoint}/{db_name}?pool=5"
db_instance:
  db_parameter_group_name: default
  db_cluster_parameter_group_name: default
  publicly_accessible: false
  source_instance:
    identifier: a
    cluster_identifier: b
  available_types:
    - db.r4.large
    - db.r4.2xlarge
    - db.r4.3xlarge
  default_instance_type: db.r4.large
```

### Command
```shell
bundle exec bin/concerto --help
```

## Warnging

This tool is not provied data mask feature. You will need to mask in other ways.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
