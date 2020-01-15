require 'thor'

class RdsConcerto::CLI < Thor
  # https://github.com/erikhuda/thor/issues/607
  include Thor::Actions
  add_runtime_options!

  desc "list", "レプリカやクローン一覧の閲覧"
  option :config, aliases: "-c", default: RdsConcerto::DEFAULT_CONFIG_FILE_NAME, desc: "設定ファイル"
  def list(stdout=true)
    out = ''
    out += show_replica
    out << "\n"
    out += show_clones
    out << "\n"
    if stdout
      puts out
    else
      out
    end
  end

  desc "create NAME(レプリカを選択したい場合。指定しなければ適当に選びます)", "インスタンスの作成"
  option :type, aliases: "-t", default: nil, desc: "インスタンスタイプ"
  option :config, aliases: "-c", default: RdsConcerto::DEFAULT_CONFIG_FILE_NAME, desc: "設定ファイル"
  def create
    concerto = RdsConcerto::Aurora.new(config_path: options[:config])
    concerto.clone!(klass: options[:type], dry_run: options[:pretend])
  end

  desc "destroy NAME", "インスタンスの削除"
  option :config, aliases: "-c", default: RdsConcerto::DEFAULT_CONFIG_FILE_NAME,  desc: "設定ファイル"
  option :name, desc: "instance identifier of delete target"
  def destroy(name=nil)
    concerto = RdsConcerto::Aurora.new(config_path: options[:config])
    concerto.destroy!(name: name || options[:name], dry_run: options[:pretend])
  end

  # desc "url NAME(URL を取得するインスタンスを指定したい場合。指定しなければ適当に選びます)", "インスタンスに接続するための URL の取得"
  # def url(name = nil)
  #   instance =
  #     if name
  #       concerto.clone_list.detect {|i| i[:name] == name }
  #     else
  #       concerto.clone_list.first
  #     end
  #   unless instance
  #     puts "Instance is not existing."
  #     exit(1)
  #   end
  #   url = `xxx`.chomp
  #   if url == ""
  #     puts "Please auth on heroku CLI."
  #     exit(1)
  #   end
  #   uri = URI.parse(url)
  #   uri.host = instance[:endpoint]
  #   puts uri.to_s
  # end

  private

  def show_replica
    concerto = RdsConcerto::Aurora.new(config_path: options[:config])
    out = "-source db instances-"
    row = <<~EOH
      -------
      name: %{name}
      size: %{size}
      engine: %{engine}
      version: %{version}
      endpoint: %{endpoint}
      status: %{status}
      created_at: %{created_at}
    EOH

    if concerto.source_db_instance
      out << row % concerto.source_db_instance
    end
    out
  end

  def show_clones
    concerto = RdsConcerto::Aurora.new(config_path: options[:config])
    out = "-クローン-"
    row = <<~EOH
      -------
      name: %{name}
      size: %{size}
      engine: %{engine}
      version: %{version}
      endpoint: %{endpoint}
      status: %{status}
      created_at: %{created_at}
      tags: %{tag}
    EOH
    concerto.cloned_instances.each do |hash|
      out << row % hash
    end
    out
  end
end
