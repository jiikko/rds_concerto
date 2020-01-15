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
    :db_subnet_group_name

  def initialize(hash)
    @source_identifier = hash.dig('db_instance', 'source', 'identifier')
    @source_cluster_identifier = hash.dig('db_instance', 'source', 'cluster_identifier')
    @region = hash.dig('aws', 'region')
    @aws_account_id = hash.dig('aws', 'account_id')
    @default_instance_type = hash.dig('db_instance', 'new', 'default_instance_type')
    @available_types = hash.dig('db_instance', 'new', 'available_types')
    @db_parameter_group_name = hash.dig('db_instance', 'new', 'db_parameter_group_name')
    @db_cluster_parameter_group_name = hash.dig('db_instance', 'new', 'db_cluster_parameter_group_name')
    @db_subnet_group_name = hash.dig('db_instance', 'new', 'db_subnet_group_name')
  end
end
