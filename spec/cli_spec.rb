RSpec.describe RdsConcerto::CLI do
  let(:valid_yaml_file) do
    yaml = <<~YAML
      aws:
        region: ap-northeast-1
        access_key_id: <%= '11111111' %>
        secret_access_key: <%= '44' %>
        account_id: 111111111
      database_url_format: "mysql2://{db_user:{db_password}@#%{db_endpoint}/{db_name}?pool=5"
      db_instance:
        source:
          identifier: yabai
          cluster_identifier: b
        new:
          db_parameter_group_name: default
          db_cluster_parameter_group_name: default
          publicly_accessible: false
          available_types:
            - db.r4.large
            - db.r4.2xlarge
            - db.r4.3xlarge
          default_instance_type: db.r4.large
    YAML
    file = Tempfile.new('yaml')
    File.open(file.path, 'w') { |f| f.puts yaml }
    file
  end
  let(:time) { Time.parse('2011-11-11 10:00:00+00') }

  describe 'create' do
    context 'empty config file' do
      it 'error' do
        allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(stub_responses: true)
        file = Tempfile.new('yaml')
        File.open(file.path, 'w') { |f| f.puts 'aaa:' }

        expect {
          RdsConcerto::CLI.new.invoke(:create, [], { type: {}, config: file.path })
        }.to raise_error(RuntimeError, /Check config yaml/)
      end
    end
    context 'have no source db' do
      it 'error' do
        allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(stub_responses: true)
        expect {
          RdsConcerto::CLI.new.invoke(:create, [], { type: {}, config: valid_yaml_file.path })
        }.to raise_error(RuntimeError, /source db instance do not found/)
      end
    end
    context 'have 1 source db' do
      it 'be success' do
        allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(
          stub_responses: {
            describe_db_instances: {
              db_instances: [
                { db_instance_identifier: 'yabai', db_instance_class: 'yabai', engine: 'large.2x',
                  engine_version: '1.0', endpoint: { address: 'goo.com' }, db_instance_status: 'available', instance_create_time: time },
              ]
            }
          }
        )
        expect(
          RdsConcerto::CLI.new.invoke(:create, [], { type: nil, config: valid_yaml_file.path })
        ).to be_truthy
        expect(
          RdsConcerto::CLI.new.invoke(:create, [], { config: valid_yaml_file.path })
        ).to be_truthy
      end
    end
  end

  describe 'destroy' do
    context 'when it assigns db instance that do not exist' do
      it 'error' do
        allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(stub_responses: true)
        expect {
          RdsConcerto::CLI.new.invoke(:destroy, [], { name: 'a', config: valid_yaml_file.path })
        }.to raise_error(RuntimeError, 'command failed. do not found resource.')
      end
      it 'do not delete source db instance' do
        allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(
          stub_responses: {
            describe_db_instances: {
              db_instances: [
                { db_instance_identifier: 'deleted', db_instance_class: 'yabai', engine: 'large.2x',
                  engine_version: '1.0', endpoint: { address: 'goo.com' }, db_instance_status: 'available', instance_create_time: time },
              ]
            }
          }
        )
        expect {
          RdsConcerto::CLI.new.invoke(:destroy, [], { name: 'yabai', config: valid_yaml_file.path })
        }.to raise_error(RuntimeError, /can not delete source resource/)
      end
    end
    it 'be success' do
      allow_any_instance_of(RdsConcerto::Aurora::Resource).to receive(:delete!)
      allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(
        stub_responses: {
          describe_db_instances: {
            db_instances: [
              { db_instance_identifier: 'deleted', db_instance_class: 'yabai', engine: 'large.2x',
                engine_version: '1.0', endpoint: { address: 'goo.com' }, db_instance_status: 'available', instance_create_time: time },
            ]
          }
        }
      )
      RdsConcerto::CLI.new.invoke(:destroy, [], { name: 'deleted', config: valid_yaml_file.path })
    end
  end

  describe 'list' do
    context 'replica has no instance' do
      before do
        allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(stub_responses: true)
      end
      it "return String" do
        actual = RdsConcerto::CLI.new.invoke(:list, [false], { config: valid_yaml_file.path })
        expected = <<~EOH
        -source db instances-
        -クローン-
        EOH
        expect(actual).to eq(expected)
      end
    end
    context 'replica has two instance' do
      before do
        time = Time.parse('2011-11-11 10:00:00+00')
        allow(RdsConcerto::Aurora).to receive(:rds_client_args).and_return(
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
      it "return String" do
        actual = RdsConcerto::CLI.new.invoke(:list, [false], { config: valid_yaml_file.path })
        expected = <<~EOH
        -source db instances-
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
