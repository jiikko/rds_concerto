require 'erb'
require 'yaml'
require 'aws-sdk-rds'

module RdsAuroraConcerto::Aurora
  DEFAULT_FILE_NAME = './.concert.yml'
  def self.new(config_path: nil)
    config_path = config_path || ENV['CONCERT_CONFIG_PATH'] || './.concert.yml'
    yaml = File.open(config_path)
    hash = YAML.load(ERB.new(yaml.read).result) || raise('yaml parse error')
    Client.new(
      config: Config.new(hash),
      rds_client: Aws::RDS::Client.new(rds_client_args(hash)),
    )
  end

  def self.rds_client_args(hash)
    { region: 'ap-northeast-1',
      access_key_id: hash['aws']['access_key_id'].to_s,
      secret_access_key: hash['aws']['secret_access_key'].to_s,
    }
  end

  class Config
    attr_reader \
      :source_identifier,
      :source_cluster_identifier,
      :region,
      :aws_account_id,
      :default_instance_type,
      :available_types,
      :db_parameter_group_name,
      :db_cluster_parameter_group_name,
      :vpc

    def initialize(hash)
      @source_identifier = hash.dig('db_instance', 'source_instance', 'identifier')
      @source_cluster_identifier = hash.dig('db_instance', 'source_instance', 'cluster_identifier')
      @region = hash.dig('aws', 'region')
      @aws_account_id = hash.dig('aws', 'account_id')
      @default_instance_type = hash.dig('db_instance', "default_instance_type")
      @available_types = hash.dig('db_instance', "available_types")
      @db_parameter_group_name = hash.dig('db_instance', 'db_parameter_group_name')
      @db_cluster_parameter_group_name = hash.dig('db_instance', 'db_cluster_parameter_group_name')
      @vpc = hash.dig('db_instance', 'vpc')
    end
  end

  class Client
    attr_reader :config, :rds_client

    def initialize(rds_client: , config: )
      @config = config
      @rds_client = rds_client
    end

    def source_list(condition: :all)
      replica_list(condition: :available)
    end

    def replica_list(condition: :all)
      replica = self.all_list.select { |x| x[:name] == config.source_identifier }
      case condition
      when :all
        replica
      when :available
        replica.select { |x| x[:status] == "available" }
      end
    end

    def cloned_list
      self.all_list.reject{|x| x[:name] == config.source_identifier }
    end

    def all_list
      rds_client.describe_db_instances.db_instances.map do |db_instance|
        response = rds_client.list_tags_for_resource(
          resource_name: get_arn(identifier: db_instance.db_instance_identifier)
        )
        { name: db_instance.db_instance_identifier,
          size: db_instance.db_instance_class,
          engine: db_instance.engine,
          version: db_instance.engine_version,
          storage: db_instance.allocated_storage,
          endpoint: db_instance.endpoint&.address,
          status: db_instance.db_instance_status,
          created_at: db_instance.instance_create_time,
          tag: response.tag_list.map(&:to_hash),
        }
      end
    end

    def clone!(instance_name: nil, klass: nil, identifier: nil)
      unless instance_name
        list = source_list
        if list.empty?
          raise 'source db instance do not found'
        end
        instance_name = list[0][:name]
      end
      klass ||= config.default_instance_type

      name = "#{instance_name}-clone-#{Time.now.to_i}"
      identifier_value = identifier || `hostname`.chomp[0..10]
      tags = [{ key: "created_by", value: identifier_value }]
      create_resouces!(name: name, tags: tags, instance_class: klass)
    end

    def destroy!(name: nil, skip_final_snapshot: true)
      if [ config.source_identifier, config.source_cluster_identifier].include?(name)
        raise 'command failed. can not delete source resource.'
      end
      unless replica_list.map(&:name).include?(name)
        raise 'command failed. do not found resource.'
      end
      delete_resouces!(name: name, skip_final_snapshot: skip_final_snapshot)
    end

    private

    def get_arn(identifier: )
      "arn:aws:rds:#{config.region}:#{config.aws_account_id}:db:#{identifier}"
    end

    def create_resouces!(name: , tags: , instance_class: )
      { db_cluster_response: restore_db_cluster!(name: name, tags: tags),
        db_instance_response: create_db_instance!(name: name, tags: tags, instance_class: instance_class),
      }
    end

    def restore_db_cluster!(name: , tags: )
      rds_client.restore_db_cluster_to_point_in_time(
        db_cluster_identifier: name,
        source_db_cluster_identifier: config.source_cluster_identifier,
        restore_type: "copy-on-write",
        use_latest_restorable_time: true,
        db_cluster_parameter_group_name: config.db_cluster_parameter_group_name,
        tags: tags,
      )
    end

    def create_db_instance!(name: , tags: , instance_class: )
      rds_client.create_db_instance(
        db_instance_identifier: name,
        db_cluster_identifier: name,
        db_instance_class: instance_class,
        engine: "aurora",
        multi_az: false,
        publicly_accessible: true,
        db_subnet_group_name: "default",
        vpc: config.vpc,
        db_parameter_group_name: config.db_parameter_group_name,
        tags: tags,
      )
    end

    def delete_resouces!(name: , skip_final_snapshot: )
      { db_instance_response: rds_client.delete_db_instance(db_instance_identifier: name, skip_final_snapshot: skip_final_snapshot),
        rdb_cluster_response: rds_client.delete_db_cluster(db_cluster_identifier: name, skip_final_snapshot: skip_final_snapshot),
      }
    end
  end
end
