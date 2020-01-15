class RdsConcerto::Aurora::Resource
  attr_reader :name, :rds_client

  def initialize(rds_client: , name: )
    @rds_client = rds_client
    @name = name
  end

  def delete!(skip_final_snapshot: )
    { db_instance_response: rds_client.delete_db_instance(db_instance_identifier: name, skip_final_snapshot: skip_final_snapshot),
      rdb_cluster_response: rds_client.delete_db_cluster(db_cluster_identifier: name, skip_final_snapshot: skip_final_snapshot),
    }
  end

  def create!(tags: , instance_class: )
    { db_cluster_response: restore_db_cluster!(name: name, tags: tags),
      db_instance_response: create_db_instance!(name: name, tags: tags, instance_class: instance_class),
    }
  end

  private

  def restore_db_cluster!(name: , tags: )
    rds_client.restore_db_cluster_to_point_in_time(
      db_cluster_identifier: name,
      source_db_cluster_identifier: RdsConcerto::Config.source_cluster_identifier,
      restore_type: "copy-on-write",
      use_latest_restorable_time: true,
      db_cluster_parameter_group_name: RdsConcerto::Config.db_cluster_parameter_group_name,
      db_subnet_group_name: RdsConcerto::Config.db_subnet_group_name,
      tags: tags,
    )
  end

  def create_db_instance!(name: , tags: , instance_class: )
    rds_client.create_db_instance(
      db_instance_identifier: name,
      db_cluster_identifier: name,
      db_instance_class: instance_class,
      engine: "aurora-mysql",
      multi_az: false,
      publicly_accessible: true,
      db_subnet_group_name: RdsConcerto::Config.db_subnet_group_name,
      db_parameter_group_name: RdsConcerto::Config.db_parameter_group_name,
      tags: tags,
    )
  end
end
