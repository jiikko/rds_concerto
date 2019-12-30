RSpec.describe RdsAuroraConcerto::CLI do
  describe 'create' do
    let(:config_path) do
      yaml = <<~YAML
          aws:
            region: ap-northeast-1
            access_key_id: <%= '11111111' %>
            secret_access_key: <%= '44' %>
            account_id: 111111111
          database_url_format: "mysql2://{db_user:{db_password}@#%{db_endpoint}/{db_name}?pool=5"
          db_instance:
            db_parameter_group_name: default
            db_cluster_parameter_group_name: default
            publicly_accessible: false
            source_instance:
              identifier: a
              cluster_identifier: b
            available_types:
              - db.r4.large
              - db.r4.2xlarge
              - db.r4.3xlarge
            default_instance_type: db.r4.large
      YAML
      file = Tempfile.new('yaml')
      File.open(file.path, 'w') { |f| f.puts yaml }
      file.path
    end
    context 'have no source db' do
      before do
        allow(RdsAuroraConcerto::Aurora).to receive(:rds_client_args).and_return(stub_responses: true)
        expect {
          RdsAuroraConcerto::CLI.new.invoke(:create, [], { type: {}, config: config_path })
        }.to raise_error(RuntimeError)
      end
      it 'error' do
      end
    end
  end

  describe 'list' do
    context 'replica has no instance' do
      let(:config_path) do
        yaml = <<~YAML
          aws:
            region: ap-northeast-1
            access_key_id: <%= '11111111' %>
            secret_access_key: <%= '44' %>
            account_id: 111111111
          database_url_format: "mysql2://{db_user:{db_password}@#%{db_endpoint}/{db_name}?pool=5"
          db_instance:
            db_parameter_group_name: default
            db_cluster_parameter_group_name: default
            publicly_accessible: false
            source_instance:
              identifier: a
              cluster_identifier: b
            available_types:
              - db.r4.large
              - db.r4.2xlarge
              - db.r4.3xlarge
            default_instance_type: db.r4.large
        YAML
        file = Tempfile.new('yaml')
        File.open(file.path, 'w') { |f| f.puts yaml }
        file.path
      end
      before do
        allow(RdsAuroraConcerto::Aurora).to receive(:rds_client_args).and_return(stub_responses: true)
      end
      it "return String" do
        actual = RdsAuroraConcerto::CLI.new.invoke(:list, [false], { config: config_path })
        expected = <<~EOH
        -レプリカ-
        -クローン-
        EOH
        expect(actual).to eq(expected)
      end
    end

    context 'replica has thow instance' do
      let(:config_path) do
        yaml = <<~YAML
          aws:
            region: ap-northeast-1
            access_key_id: <%= '11111111' %>
            secret_access_key: <%= '44' %>
            account_id: 111111111
          database_url_format: "mysql2://{db_user:{db_password}@#%{db_endpoint}/{db_name}?pool=5"
          db_instance:
            db_parameter_group_name: default
            db_cluster_parameter_group_name: default
            publicly_accessible: false
            source_instance:
              identifier: a
              cluster_identifier: b
            available_types:
              - db.r4.large
              - db.r4.2xlarge
              - db.r4.3xlarge
            default_instance_type: db.r4.large
        YAML
        file = Tempfile.new('yaml')
        File.open(file.path, 'w') { |f| f.puts yaml }
        file.path
      end
      before do
        time = Time.parse('2011-11-11 10:00:00+00')
        allow(RdsAuroraConcerto::Aurora).to receive(:rds_client_args).and_return(
          stub_responses: {
            list_tags_for_resource: {
              tag_list: [{ key: 'created_at', value: 'izumikonata' }]
            },
            describe_db_instances: {
              db_instances: [
                { db_instance_identifier: '1', db_instance_class: 'yabai', engine: 'large.2x',
                  engine_version: '1.0', endpoint: { address: 'goo.com' }, db_instance_status: 'avalable', instance_create_time: time },
              { db_instance_identifier: '2', db_instance_class: 'sugoi', engine: 'large.3x',
                engine_version: '1.1', endpoint: { address: 'goo.com' }, db_instance_status: 'avalable', instance_create_time: time },
              ]
            }
          }
        )
      end

      it "return Strung" do
        actual = RdsAuroraConcerto::CLI.new.invoke(:list, [false], { config: config_path })
        expected = <<~EOH
        -レプリカ-
        -クローン--------
        name: 1
        size: yabai
        engine: large.2x
        version: 1.0
        endpoint: goo.com
        status: avalable
        created_at: 2011-11-11 10:00:00 UTC
        tags: [{:key=>"created_at", :value=>"izumikonata"}]
        -------
        name: 2
        size: sugoi
        engine: large.3x
        version: 1.1
        endpoint: goo.com
        status: avalable
        created_at: 2011-11-11 10:00:00 UTC
        tags: [{:key=>"created_at", :value=>"izumikonata"}]
        EOH
        expect(actual.chomp).to eq(expected)
      end
    end
  end
end
