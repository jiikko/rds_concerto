require 'singleton'

class Config
  include Singleton

  class << self
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

    def configure_from_hash(hash)
      @source_identifier = hash.dig('db_instance', 'source', 'identifier')
      @source_cluster_identifier = hash.dig('db_instance', 'source', 'cluster_identifier')
      @region = hash.dig('aws', 'region')
      @aws_account_id = hash.dig('aws', 'account_id')
      @default_instance_type = hash.dig('db_instance', 'new', 'default_instance_type')
      @available_types = hash.dig('db_instance', 'new', 'available_types')
      @db_parameter_group_name = hash.dig('db_instance', 'new', 'db_parameter_group_name')
      @db_cluster_parameter_group_name = hash.dig('db_instance', 'new', 'db_cluster_parameter_group_name')
      @db_subnet_group_name = hash.dig('db_instance', 'new', 'db_subnet_group_name')

      @errors = []
    end

    def valid?
      true
      validate_presence
      return @errors.empty?
    end

    def errors
      @errors.join("\n")
    end

    def validate_presence
      requireds =
        %w( source_identifier
          source_cluster_identifier
          region
          aws_account_id
          default_instance_type
          available_types
          db_parameter_group_name
          db_cluster_parameter_group_name
      )
      blank_names = []
      requireds.each do |name|
        if public_send(name).nil?
          blank_names << name
        end
      end
      unless blank_names.empty?
        @errors << "Need #{blank_names.join(', ')}. Check config yaml"
      end
    end
  end
end
