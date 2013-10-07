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

# Include cookbook-delayed_evaluator for delaying evaluation of node attributes
# to converge phase instead of compile phase
include_recipe 'delayed_evaluator'

# Create an instance of RightscaleVolume provider to access private helper methods using 'send'
# See rightscale_volume/libraries/provider_rightscale_volume.rb for more information
provider = Chef::Provider::RightscaleVolume.new('test', nil)

# Set minimum volume size to 100GB for Rackspace Open Clouds (cloud-specific feature)
volume_size = node[:cloud][:provider] == 'rackspace-ng' ? 100 : 10


# *** Testing actions supported by the rightscale_volume cookbook ***


# --- TESTING 'action_create' - creates a new volume in the cloud ---

# Add a visual marker in the Chef logs for better log readability
marker 'creating volume 1' do
  template 'rightscale_audit_entry.erb'
end

# Create volume 1 using the rightscale_volume cookbook
rightscale_volume 'test_device_1_DELETE_ME' do
  size volume_size
  description "test device created from rightscale_volume cookbook"
  action :create
end

# Ensure that the volume was created in the cloud
ruby_block "ensure volume 1 created" do
  block do
    # Call find_volumes method to retrieve specific volumes in the cloud
    # See 'find_volumes' method in rightscale_volume/libraries/provider_rightscale_volume.rb for more information
    created_volume = provider.send(
      :find_volumes,
      # 'lazy' block ensures the node attribute is evaluated during converge phase
      :resource_uid => lazy{ node['rightscale_volume']['test_device_1_DELETE_ME']['volume_id'] }
    )
    raise 'Volume creation failed!' if created_volume.empty?
  end
end

# --- END TESTING 'action_create' ---


# --- TESTING 'action_snapshot' - takes a snapshot of the volume ---

# Add a visual marker in the Chef logs for better log readability
marker 'taking a snapshot of volume 1' do
  template 'rightscale_audit_entry.erb'
end

# Take a snapshot of volume 1
rightscale_volume 'test_device_1_DELETE_ME' do
  snapshot_name 'test_device_DELETE_ME_snapshot'
  action :snapshot
end

# Ensure that the snapshot was created in the cloud
ruby_block "ensure snapshot of volume 1 created" do
  block do
    # Call get_snapshots method to retrieve all snapshots of a volume
    # See 'get_snapshots' method in rightscale_volume/libraries/provider_rightscale_volume.rb for more information
    snapshots_list = provider.send(
      :get_snapshots,
      # 'lazy' block ensures the node attribute is evaluated during converge phase
      lazy { node['rightscale_volume']['test_device_1_DELETE_ME']['volume_id'] }
    )
    raise 'No snapshots were created for this volume' if snapshots_list.empty?
  end
end

# --- END TESTING 'action_snapshot' ---


# --- TESTING 'action_create' - creates a new volume from a snapshot in the cloud ---

# Add a visual marker in the Chef logs for better log readability
marker 'creating volume 2 from the snapshot' do
  template 'rightscale_audit_entry.erb'
end

# Create volume 2 from the snapshot of volume 1
rightscale_volume 'test_device_2_DELETE_ME' do
  size volume_size
  description "test device created from rightscale_volume cookbook"
  snapshot_id snapshots_list.first.show.resource_uid
  action :create
end

# Ensure that the volume was created in the cloud
ruby_block "ensure volume 2 created from snapshot" do
  block do
    # Call find_volumes method to retrieve specific volumes in the cloud
    # See 'find_volumes' method in rightscale_volume/libraries/provider_rightscale_volume.rb for more information
    created_volume = provider.send(
      :find_volumes,
      # 'lazy' block ensures the node attribute is evaluated during converge phase
      :resource_uid => lazy { node['rightscale_volume']['test_device_2_DELETE_ME']['volume_id'] }
    )
    raise 'Volume creation from snapshot failed!' if created_volume.empty?
  end
end

# --- END TESTING 'action_create' ---


# --- TESTING 'action_cleanup' - cleans up old snapshots of a volume ---

# Add a visual marker in the Chef logs for better log readability
marker 'cleanup existing snapshots for volume 1' do
  template 'rightscale_audit_entry.erb'
end

# Clean up snapshots taken from volume 1
rightscale_volume 'test_device_1_DELETE_ME' do
  max_snapshots 0
  action :cleanup
end

# Ensure that the snapshots got cleaned up
ruby_block 'ensure volume 1 snapshots cleaned up' do
  block do
    # Call get_snapshots method to retrieve all snapshots of a volume
    # See 'get_snapshots' method in rightscale_volume/libraries/provider_rightscale_volume.rb for more information
    snapshots_list = provider.send(
      :get_snapshots,
      # 'lazy' block ensures the node attribute is evaluated during converge phase
      lazy { node['rightscale_volume']['test_device_1_DELETE_ME']['volume_id'] }
    )
    raise 'No snapshots were created for this volume' unless snapshots_list.empty?
  end
end

# --- END TESTING 'action_cleanup' ---


# --- TESTING 'action_delete' - deletes a volume from the cloud ---

# Store the volume_id in the node to a temporary variable since deleting the volume
# will also destroy all information in the node
# 'lazy' block ensures the node attribute is evaluated during converge phase
volume_id = lazy { node['rightscale_volume']['test_device_1_DELETE_ME']['volume_id'] }

# Add a visual marker in the Chef logs for better log readability
marker 'deleting volume 1' do
  template 'rightscale_audit_entry.erb'
end

# Delete volume 1
rightscale_volume 'test_device_1_DELETE_ME' do
  action :delete
end

# Ensure that volume 1 was deleted from the cloud
ruby_block 'ensure volume 1 deleted' do
  block do
    # Call find_volumes method to retrieve specific volumes in the cloud
    # See 'find_volumes' method in rightscale_volume/libraries/provider_rightscale_volume.rb for more information
    volume = provider.send(:find_volumes, :resource_uid => volume_id)
    raise 'Volume was not successfully deleted' unless volume.nil?
  end
end

# --- END TESTING 'action_delete' ---


# --- TESTING 'action_attach' - attach volumes to a RightScale instance ---

devices_before_attach = []
ruby_block 'get devices before attach' do
  block do
    # Call attached_devices method to get a list of volumes attached to the instance before attaching a new volume
    # See 'attached_devices' method in rightscale_volume/libraries/provider_rightscale_volume.rb for more information
    devices_before_attach = provider.send(:attached_devices)
  end
end

# Add a visual marker in the Chef logs for better log readability
marker 'attaching volume 2' do
  template 'rightscale_audit_entry.erb'
end

# Attach volume 2
rightscale_volume 'test_device_2_DELETE_ME' do
  action :attach
end

# Ensure that volume 2 is attached to the instance
ruby_block 'ensure volume 2 attached' do
  block do
    # Call attached_devices method to get a list of volumes attached to an instance after the attach action
    devices_after_attach = provider.send(:attached_devices)
    raise 'Volume was not attached successfully!' if devices_after_attach.size == devices_before_attach.size
  end
end

# --- END TESTING 'action_attach' ---


# --- TESTING 'action_detach' - detaches a volume from the instance ---

devices_before_detach = []
ruby_block 'get devices before detach' do
  block do
    # Call attached_devices method to get a list of volumes attached to the instance before detaching a volume
    devices_before_detach = provider.send(:attached_devices)
  end
end

# Add a visual marker in the Chef logs for better log readability
marker 'detaching volume 2' do
  template 'rightscale_audit_entry.erb'
end

# Detach volume 2
rightscale_volume 'test_device_2_DELETE_ME' do
  action :detach
end

# Ensure that volume 2 is detached from the instance
ruby_block 'ensure volume 2 detached' do
  block do
    # Call attached_devices method to get a list of volumes attached to the instance after detaching a volume
    devices_after_detach = provider.send(:attached_devices)
    raise 'Volume was not detached successfully!' unless devices_after_detach.size == devices_before_detach.size
  end
end

# --- END TESTING 'action_detach' ---


# --- TESTING 'action_delete' - deletes a volume from the cloud ---

# Add a visual marker in the Chef logs for better log readability
marker 'deleting volume 2' do
  template 'rightscale_audit_entry.erb'
end

# Delete volume 2
rightscale_volume 'test_device_2_DELETE_ME' do
  action :delete
end

# Ensure that volume 2 was deleted from the cloud
ruby_block 'ensure volume 2 deleted' do
  block do
    # Call find_volumes method to retrieve specific volumes in the cloud
    # See 'find_volumes' method in rightscale_volume/libraries/provider_rightscale_volume.rb for more information
    volume = provider.send(:find_volumes, :name => 'test_device_2_DELETE_ME')
    raise 'Volume was not successfully deleted' unless volume.nil?
  end
end

# --- END TESTING 'action_delete' ---
