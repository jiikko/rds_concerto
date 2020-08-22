class RdsConcerto::Aurora::Client
  attr_reader :rds_client

  def initialize(rds_client: )
    @rds_client = rds_client
  end

  def source_db_instance
    @source_db_instance ||= self.all_instances.detect { |x| x[:name] == RdsConcerto::Config.source_identifier }
  end

  def cloned_instances
    list = self.all_instances.reject { |x| x[:name] == RdsConcerto::Config.source_identifier }
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
    klass ||= RdsConcerto::Config.default_instance_type
    RdsConcerto::Aurora::Resource.new(rds_client: rds_client, name: name).
      create!(tags: tags, instance_class: klass) unless dry_run
  end

  def destroy!(name: nil, skip_final_snapshot: true, dry_run: false)
    if [RdsConcerto::Config.source_identifier, RdsConcerto::Config.source_cluster_identifier].include?(name)
      raise 'Command failed. Can not delete source resource.'
    end
    if not cloned_instances.map { |x| x[:name] }.include?(name)
      raise 'Command failed. Do not found resource.'
    end
    RdsConcerto::Aurora::Resource.new(rds_client: rds_client, name: name).
      delete!(skip_final_snapshot: skip_final_snapshot) unless dry_run
  end

  def url(name)
    unless RdsConcerto::Config.has_vals_for_url_command?
      raise 'Please set vals in `.concerto.yaml`.'
    end
    instance =
      if name
        cloned_instances.detect {|i| i[:name] == name }
      else
        cloned_instances.first
      end
    unless instance
      puts "Instance is not existing."
      exit(1)
    end
    unless instance[:endpoint]
      puts "A instance is continue preparing."
      exit(1)
    end
    RdsConcerto::Config.database_url_format.gsub('{{endpoint}}', instance[:endpoint])
  end

  def start_from_stopping(name, dry_run: false)
    if not cloned_instances.map { |x| x[:name] }.include?(name)
      raise 'Command failed. Do not found resource.'
    end
    RdsConcerto::Aurora::Resource.new(rds_client: rds_client, name: name).start! unless dry_run
  end

  def stop_from_available(name, dry_run: false)
    if not cloned_instances.map { |x| x[:name] }.include?(name)
      raise 'Command failed. Do not found resource.'
    end
    RdsConcerto::Aurora::Resource.new(rds_client: rds_client, name: name).stop! unless dry_run
  end

  private

  def get_arn(identifier: )
    "arn:aws:rds:#{RdsConcerto::Config.region}:#{RdsConcerto::Config.aws_account_id}:db:#{identifier}"
  end

  def clone_instance_name_base
    source = source_db_instance
    unless source
      raise 'Source db instance do not found'
    end
    unless source[:status] == "available"
      raise 'Source db instance do not available'
    end
    instance_name = source[:name]
    "#{source[:name]}-clone"
  end

end
