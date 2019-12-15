require 'erb'
require 'yaml'
require 'aws-sdk-rds'

module RdsAuroraConcerto::Aurora
  def self.new
    yaml = File.open('./.concert.yml' || ENV['CONCERT_CONFIG_PATH'])
    hash = YAML.load(ERB.new(yaml.read).result)
    Client.new(
      config: Config.new(hash),
      rds_client: Aws::RDS::Client.new(
        region: 'ap-northeast-1',
        access_key_id: hash['aws']['access_key_id'].to_s,
        secret_access_key: hash['aws']['secret_access_key'].to_s,
      )
    )
  end

  class Config
    attr_reader \
      :source_identifier,
      :source_cluster_identifier,
      :region,
      :aws_account_id

    def initialize(hash)
      @source_identifier = hash['source_instance']['identifier']
      @source_cluster_identifier = hash['source_instance']['cluster_identifier']
      @region = hash['region']
      @aws_account_id = hash['aws']['account_id']
    end
  end

  class Client
    attr_reader :rds_client, :config

    def initialize(rds_client: , config: )
      @config = config
      @rds_client = rds_client
    end

    def replica_list(condition: :all)
      replica = self.all_list.select{|x| x[:name] == config.source_identifier }
      case condition
      when :all
        replica
      when :available
        replica.select{|x| x[:status] == "available" }
      end
    end

    def cloned_list
      self.all_list.reject{|x| x[:name] == confgi.instance_identifier }
    end

    def all_list
      rds_client.describe_db_instances.db_instances.map do |db_instance|
        response = rds_client.list_tags_for_resource(
          resource_name: get_arn(identifier: db_instance.db_instance_identifier)
        )
        { name: x.db_instance_identifier,
          size: x.db_instance_class,
          engine: x.engine,
          version: x.engine_version,
          storage: x.allocated_storage,
          endpoint: x.endpoint&.address,
          status: x.db_instance_status,
          created_at: x.instance_create_time,
          tag: response.tag_list.map(&:to_hash),
        }
      end
    end

    def clone!(name: nil, instance: "", klass: "db.r4.large", identifier: nil)
      unless name
        name = "#{instance}-clone-#{Time.now.to_i}"
      end
      identifier_value = identifier || `hostname`.chomp
      tags = [{ key: "created_by", value: identifier_value }]
      create_resouces!(name: name, tags: tags, instance_class: klass)
    end

    def destroy!(name: nil, skip_final_snapshot: true)
      return if [config.source_identifier,
                 config.source_cluster_identifier].include?(name)
      delete_resouces!(name: name, skip_final_snapshot: skip_final_snapshot)
    end

    private

    def get_arn(region: , identifier: )
      "arn:aws:rds:#{config.region}:#{config.aws_account_id}:db:#{identifier}"
    end

    def create_resouces!(name: , tags: ,instance_class: )
      restore_db_cluster!(name: name, tags: tags)
      create_db_instance!(name: name, tags: tags, instance_class: klass)
    end

    def restore_db_cluster!(name: , tags: )
      rds_client.restore_db_cluster_to_point_in_time(
        db_cluster_identifier: name,
        source_db_cluster_identifier: config.source_cluster_identifier,
        restore_type: "copy-on-write",
        use_latest_restorable_time: true,
        db_cluster_parameter_group_name: "concerto-aurora-56-cluster",
        tags: tags,
      )
    end

    def create_db_instance!(name: , instance_class: ,  tags: )
      rds_client.create_db_instance(
        db_instance_identifier: name,
        db_cluster_identifier: name,
        db_instance_class: instance_class,
        engine: "aurora",
        multi_az: false,
        publicly_accessible: true,
        db_subnet_group_name: "default",
        db_parameter_group_name: "concerto-aurora-56",
        tags: tags,
      )
    end

    def delete_resouces!(name: , skip_final_snapshot: )
      rds_client.delete_db_instance(db_instance_identifier: name, skip_final_snapshot: skip_final_snapshot)
      rds_client.delete_db_cluster(db_cluster_identifier: name, skip_final_snapshot: skip_final_snapshot)
    end
  end
end
