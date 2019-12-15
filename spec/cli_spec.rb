RSpec.describe RdsAuroraConcerto::CLI do
  describe 'list' do
    context 'replica has non instance' do
      before do
        time = Time.parse('2011-11-11 10:00:00')
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

      it "return list" do
        actual = RdsAuroraConcerto::CLI.new.list(stdout: false)
        expected = <<~EOH
        -レプリカ-
        -クローン--------
        name: 1
        size: yabai
        engine: large.2x
        version: 1.0
        endpoint: goo.com
        status: avalable
        created_at: 2011-11-11 01:00:00 UTC
        tags: [{:key=>"created_at", :value=>"izumikonata"}]
        -------
        name: 2
        size: sugoi
        engine: large.3x
        version: 1.1
        endpoint: goo.com
        status: avalable
        created_at: 2011-11-11 01:00:00 UTC
        tags: [{:key=>"created_at", :value=>"izumikonata"}]
        EOH
        expect(actual.chomp).to eq(expected)
      end
    end
  end
end
