require 'spec_helper'

describe Chef::Provider::RightscaleVolume do
  let(:provider) { Chef::Provider::RightscaleVolume.new(new_resource, run_context) }
  let(:new_resource) { Chef::Resource::RightscaleVolume.new('test_volume') }
  let(:current_resource) { Chef::Resource::RightscaleVolume.new('test_volume') }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:node) do
    node = Chef::Node.new
    node.set['rightscale_volume'] = {}
    node
  end
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  before (:all) do
    @volume_name = 'test_volume'
    @volume_size = 10
    @volume_description = 'test_volume description'
    @volume_id = 'some_id'
    @volume_status = 'available'

    new_resource.size = @volume_size
    new_resource.description = @volume_description
  end

  before (:each) do
    provider.stub(:load_current_resource).and_return(current_resource)
    provider.new_resource = new_resource
    provider.current_resource = current_resource

    @volume_stub = double('volume')
    @volume_stub.stub(
      :name => @volume_name,
      :size => @volume_size,
      :description => @volume_description,
      :resource_uid => @volume_id,
      :status => @volume_status
    )
  end

  describe "actions" do

    # Creates a test volume by stubbing out the create_volume method.
    #
    def create_test_volume
      provider.stub(:create_volume).and_return(@volume_stub)
      provider.run_action(:create)
    end

  #TODO:
  # 1) check if create call populated the node variables
  # 2) check if node variable removed after delete call

    describe "#action_create" do
      context "volume #{@volume_name} does not exist" do
        it "should create #{@volume_name}" do
          provider.should_receive(:create_volume).and_return(@volume_stub)
          provider.run_action(:create)
        end

        context "trying to create a volume with a specific ID" do
          it "should not create the volume" do
            new_resource.volume_id = 'some_id'
            provider.should_not_receive(:create_volume)
            expect {
              provider.run_action(:create)
            }.to raise_error(RuntimeError, "Cannot create a volume with specific ID.")
          end
        end

        context "given a snapshot ID" do
          it "should create a volume from the snapshot" do
            snapshot_id = 'some_snapshot_id'
            new_resource.snapshot_id = snapshot_id
            provider.should_receive(:create_volume).with(
              @volume_name,
              @volume_size,
              @volume_description,
              snapshot_id,
              nil
            ).and_return(@volume_stub)
            provider.run_action(:create)
          end
        end
      end

      context "volume #{@volume_name} already exists" do
        it "should not create a new volume" do
          create_test_volume
          provider.should_not_receive(:create_volume)
          provider.run_action(:create)
        end
      end
    end

    describe "#action_attach" do
      context "volume to be attached exists and not in use" do
        it "should attach the volume" do
          create_test_volume

          attached_device = '/dev/some_device'
          provider.stub(:device_letter_exclusions).and_return([])
          provider.should_receive(:get_next_devices).and_return(['some_device'])
          provider.should_receive(:attach_volume).and_return(attached_device)

          @volume_stub.stub(:status => 'in-use')
          volumes_stub = double("volumes", :show => @volume_stub)
          provider.should_receive(:find_volume_by_id).and_return(volumes_stub)
          provider.run_action(:attach)
        end
      end

      context "volume to be attached exists and in use" do
        it "should not attach the volume" do
          create_test_volume

          current_resource.state = 'in-use'
          provider.should_not_receive(:get_next_devices)
          provider.run_action(:attach)
        end
      end

      context "volume to be attached does not exist" do
        it "should not attach the volume" do
          provider.should_not_receive(:get_next_devices)
          provider.run_action(:attach)
        end
      end
    end

    describe "#action_snapshot" do
      context "volume to be snapshotted exists" do
        it "should take a snapshot of the volume" do
          create_test_volume

          snapshot_stub = double("snapshot")
          snapshot_stub.stub(
            :name => 'snapshot_name',
            :resource_uid => 'snapshot ID',
            :state => 'available'
          )
          provider.should_receive(:create_volume_snapshot).and_return(snapshot_stub)
          provider.run_action(:snapshot)
        end
      end

      context "volume to be snapshotted does not exist" do
        it "should not take a snapshot of the volume" do
          provider.should_not_receive(:create_volume_snapshot)
          provider.run_action(:snapshot)
        end
      end
    end

    describe "#action_detach" do
      context "volume to be detached exists and in use" do
        it "should detach the volume" do
          create_test_volume

          current_resource.state = 'in-use'
          provider.should_receive(:detach_volume).and_return(@volume_stub)

          @volume_stub.stub(:status => 'available')
          volumes_stub = double("volumes", :show => @volume_stub)
          provider.should_receive(:find_volume_by_id).and_return(volumes_stub)
          provider.run_action(:detach)
        end
      end

      context "volume to be detached exists and not in use" do
        it "should not detach the volume" do
          create_test_volume

          provider.should_not_receive(:detach_volume)
          provider.run_action(:detach)
        end
      end

      context "volume to be detached does not exist" do
        it "should not detach the volume" do
          provider.should_not_receive(:detach_volume)
          provider.run_action(:detach)
        end
      end
    end

    describe "#action_delete" do
      context "volume to be deleted exists and not in use" do
        it "should delete volume" do
          create_test_volume

          provider.should_receive(:delete_volume).and_return(true)
          provider.run_action(:delete)
        end
      end

      context "volume to be deleted exists and in use" do
        it "should not delete volume" do
          create_test_volume

          current_resource.state = 'in-use'
          provider.should_not_receive(:delete_volume)
          provider.run_action(:delete)
        end
      end

      context "volume to be deleted does not exist" do
        it "should not delete volume" do
          provider.should_not_receive(:delete_volume)
          provider.run_action(:delete)
        end
      end
    end

    describe "#action_cleanup" do
      context "volume whose snapshots need to be cleaned exists" do
        it "should clean up snapshots" do
          create_test_volume

          provider.should_receive(:cleanup_snapshots).and_return(3)
          provider.run_action(:cleanup)
        end
      end

      context "volume whose snapshots need to be cleaned does not exist" do
        it "should not clean up snapshots" do
          provider.should_not_receive(:cleanup_snapshots)
          provider.run_action(:cleanup)
        end
      end
    end
  end
end
