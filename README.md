# RdsConcerto

This gem provide feature which to clone Aurora(MySQL) instance.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rds_concerto', require: false, group: :development
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rds_concerto

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
  source:
    identifier: a
    cluster_identifier: b
  new:
    available_types:
      - db.r4.large
      - db.r4.2xlarge
      - db.r4.3xlarge
    default_instance_type: db.r4.large
    master_username: new_username
    master_user_password: new_password
    db_parameter_group_name: default
    db_cluster_parameter_group_name: default
    publicly_accessible: false
    db_subnet_group_name: default-vpc-**************
```

* db_instance.db_subnet_group_name
  * optional. need subnet name, if you want public access.
* db_instance.master_username, db_instance.master_user_password
  * optional.

### Command
```shell
bundle exec bin/concerto --help
```

## Warnging

This tool is not provied data mask feature. You will need to mask in other ways.
I think good way is to do clone from masked db. the masked db do to restore from backup each day.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## TODO
* raise error when arg do not include in available_types
* matomeru args of RdsConcerto::CLI methods
* Implement url command
  * I want to use that it like `DATABASE_URL=$(bin/concerto url) bin/rails c`
  * `DATABASE_URL=mysql2://hogehoge:hogehoge@dbdb.ap-northeast-1.rds.amazonaws.com/monomydb?pool=5`
* command log
* override mysql login and password
