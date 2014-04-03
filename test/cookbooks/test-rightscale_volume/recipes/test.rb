#
# Cookbook Name:: test-rightscale_volume
# Recipe:: test
#
# Copyright (C) 2013 RightScale, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef::Resource
  include RightscaleVolumeTest::Helper
end

include_recipe 'rightscale_volume::default'

# Set minimum volume size to 100GB for Rackspace Open Clouds (cloud-specific feature)
volume_size = node[:cloud][:provider] == 'rackspace-ng' ? 100 : 1

# Set the volume name with the current UNIX timestamp so that multiple test runs
# do not overlap each other in case of failures
timestamp = Time.now.to_i
test_volume_1 = "test_device_1_#{timestamp}_DELETE_ME"
test_volume_2 = "test_device_2_#{timestamp}_DELETE_ME"

# *** Testing actions supported by the rightscale_volume cookbook ***

log '***** TESTING action_create - create volume 1 *****'

# Create volume 1 using the rightscale_volume cookbook
rightscale_volume test_volume_1 do
  size volume_size
  description "test device created from rightscale_volume cookbook"
  action :create
end

# Ensure that the volume was created in the cloud
ruby_block "ensure volume 1 created" do
  block do
    if is_volume_created?(node['rightscale_volume'][test_volume_1]['volume_id'])
      Chef::Log.info 'TESTING action_create -- PASSED'
    else
      raise 'TESTING action_create -- FAILED'
    end
  end
end


log '***** TESTING action_attach - attach volume 1 *****'

# Attach volume 1
rightscale_volume test_volume_1 do
  action :attach
end

# Ensure that volume 1 is attached to the instance
ruby_block 'ensure volume 1 attached' do
  block do
    if is_volume_attached?(node['rightscale_volume'][test_volume_1]['volume_id'])
      Chef::Log.info 'TESTING action_attach -- PASSED'
    else
      raise 'TESTING action_attach -- FAILED'
    end
  end
end

ruby_block 'mount volume and generate random test file' do
  block do
    format_and_mount_device(node['rightscale_volume'][test_volume_1]['device'])
    generate_test_file
  end
end


log '***** TESTING action_snapshot - snasphot volume 1 *****'

# Take a snapshot of volume 1
rightscale_volume test_volume_1 do
  snapshot_name "#{test_volume_1}_snapshot"
  action :snapshot
end

# Ensure that the snapshot was created in the cloud
ruby_block "ensure snapshot of volume 1 created" do
  block do
    if is_snapshot_created?(node['rightscale_volume'][test_volume_1]['volume_id'])
      Chef::Log.info 'TESTING action_snapshot -- PASSED'
    else
      raise 'TESTING action_snapshot -- FAILED'
    end
  end
end


log '***** TESTING action_detach - detach volume 1 *****'

ruby_block 'unmount device' do
  block do
    unmount_device(node['rightscale_volume'][test_volume_1]['device'])
  end
end

# Detach volume 1
rightscale_volume test_volume_1 do
  action :detach
end

# Ensure that volume 1 is detached from the instance
ruby_block 'ensure volume 1 detached' do
  block do
    if is_volume_detached?(node['rightscale_volume'][test_volume_1]['volume_id'])
      Chef::Log.info 'TESTING action_detach -- PASSED'
    else
      raise 'TESTING action_detach -- FAILED'
    end
  end
end


log '***** TESTING action_create from snapshot - create volume 2 *****'

# Create volume 2 from the snapshot of volume 1
rightscale_volume test_volume_2 do
  size volume_size
  description "test device created from rightscale_volume cookbook"
  snapshot_id lazy{ get_snapshots(node['rightscale_volume'][test_volume_1]['volume_id']).first.show.resource_uid }
  action :create
end

# Ensure that the volume 2 was created in the cloud
ruby_block "ensure volume 2 created from snapshot" do
  block do
    if is_volume_created?(node['rightscale_volume'][test_volume_2]['volume_id'])
      Chef::Log.info 'TESTING action_create from snapshot -- PASSED'
    else
      raise 'TESTING action_create from snapshot -- FAILED'
    end
  end
end


log '***** TESTING action_cleanup - delete snapshots of volume 1 *****'

# Clean up snapshots taken from volume 1
rightscale_volume test_volume_1 do
  max_snapshots 0
  action :cleanup
end

# Ensure that the snapshots got cleaned up
ruby_block 'ensure volume 1 snapshots cleaned up' do
  block do
    if is_snapshots_cleaned_up?(node['rightscale_volume'][test_volume_1]['volume_id'])
      Chef::Log.info 'TESTING action_cleanup -- PASSED'
    else
      raise 'TESTING action_cleanup -- FAILED'
    end
  end
end


log '***** TESTING action_attach - attach volume 2 *****'

# Attach volume 2
rightscale_volume test_volume_2 do
  action :attach
end

# Ensure that volume 2 is attached to the instance
ruby_block 'ensure volume 2 attached' do
  block do
    if is_volume_attached?(node['rightscale_volume'][test_volume_2]['volume_id'])
      Chef::Log.info 'TESTING action_attach -- PASSED'
    else
      raise 'TESTING action_attach -- FAILED'
    end
  end
end


log '***** TESTING action_detach - detach volume 2 *****'

# Detach volume 2
rightscale_volume test_volume_2 do
  action :detach
end

# Ensure that volume 1 is detached from the instance
ruby_block 'ensure volume 2 detached' do
  block do
    if is_volume_detached?(node['rightscale_volume'][test_volume_2]['volume_id'])
      Chef::Log.info 'TESTING action_detach -- PASSED'
    else
      raise 'TESTING action_detach -- FAILED'
    end
  end
end


log '***** TESTING action_delete - delete volume 1 and volume 2 *****'

# Delete volume 1
rightscale_volume test_volume_1 do
  action :delete
end

# Ensure that volume 1 was deleted from the cloud
ruby_block 'ensure volume 1 deleted' do
  block do
    if is_volume_deleted?(test_volume_1)
      Chef::Log.info 'TESTING action_delete -- PASSED'
    else
      raise 'TESTING action_delete -- FAILED'
    end
  end
end

# Delete volume 2
rightscale_volume test_volume_2 do
  action :delete
end

# Ensure that volume 2 was deleted from the cloud
ruby_block 'ensure volume 2 deleted' do
  block do
    if is_volume_deleted?(test_volume_2)
      Chef::Log.info 'TESTING action_delete -- PASSED'
    elsif ['rackspace-ng', 'openstack'].include?(node['cloud']['provider'])
      Chef::Log.info 'TESTING action_delete -- SKIPPED cannot delete volume if it has dependent snapshots'
    else
      raise 'TESTING action_delete -- FAILED'
    end
  end
end
