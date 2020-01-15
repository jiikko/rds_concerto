class RdsConcerto::Aurora::Client
  attr_reader :config, :rds_client

  def initialize(rds_client: , config: )
    @config = config
    if ENV['VERBOSE_CONCERTO']
      puts @config.inspect
    end
    @rds_client = rds_client
  end

  def source_db_instance
    @source_db_instance ||= self.all_instances.detect { |x| x[:name] == config.source_identifier }
  end

  def cloned_instances
    list = self.all_instances.reject { |x| x[:name] == config.source_identifier }
    list.select { |x| /^#{clone_instance_name_base}/ =~ x[:name] }
  end

  def all_instances
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

  def clone!(instance_name: nil, klass: nil, identifier: nil, dry_run: false)
    name = "#{clone_instance_name_base}-#{Time.now.to_i}"
    identifier_value = identifier || `hostname`.chomp[0..10]
    tags = [{ key: "created_by", value: identifier_value }]
    klass ||= config.default_instance_type
    RdsConcerto::Aurora::Resource.new(rds_client: rds_client, name: name, config: config).
      create!(tags: tags, instance_class: klass) unless dry_run
  end

  def destroy!(name: nil, skip_final_snapshot: true, dry_run: false)
    if [config.source_identifier, config.source_cluster_identifier].include?(name)
      raise 'command failed. can not delete source resource.'
    end
    if not cloned_instances.map {|x| x[:name] }.include?(name)
      raise 'command failed. do not found resource.'
    end
    RdsConcerto::Aurora::Resource.new(rds_client: rds_client, name: name).
      delete!(skip_final_snapshot: skip_final_snapshot) unless dry_run
  end

  private

  def get_arn(identifier: )
    "arn:aws:rds:#{config.region}:#{config.aws_account_id}:db:#{identifier}"
  end

  def clone_instance_name_base
    source = source_db_instance
    unless source
      raise 'source db instance do not found'
    end
    unless source[:status] == "available"
      raise 'source db instance do not available'
    end
    instance_name = source[:name]
    "#{source[:name]}-clone"
  end
end
