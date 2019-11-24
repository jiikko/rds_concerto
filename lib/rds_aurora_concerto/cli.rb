require 'thor'

class RdsAuroraConcerto::CLI < Thor
  desc "list", "レプリカやクローン一覧の閲覧"
  def list
    out = ''
    out += show_replica
    out << "\n"
    out += show_clones
    out << "\n"
    puts out
  end

  desc "create NAME(レプリカを選択したい場合。指定しなければ適当に選びます)", "インスタンスの作成"
  option :type, aliases: "-t", default: "db.r4.large", desc: "インスタンスタイプ"
  def create(name = nil)
    unless name
      list = concerto.replica_list(condition: :available).first
      name = list[0][:name]
    end
    concerto.clone!(instance: name, klass: options[:type])
  end

  desc "destroy NAME(指定しなかったら全部消します)", "インスタンスの削除"
  def destroy(name = nil)
    if name
      concerto.destroy!(name: name)
    else
      concerto.cloned_list.each{|i| concerto.destroy!(name: i[:name]) }
    end
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
    out = "-レプリカ-"
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
    concerto.replica_list.each do |hash|
      out << row % hash
    end
    out
  end

  def show_clones
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
    concerto.cloned_list.each do |hash|
      out << row % hash
    end
    out
  end

  def concerto
    @concerto ||= RdsAuroraConcerto::Aurora.new
end
