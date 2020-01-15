require 'erb'
require 'yaml'
require 'aws-sdk-rds'

module RdsConcerto::Aurora
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
end
