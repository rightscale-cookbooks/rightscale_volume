#
# Cookbook Name::network_storage
#
# Copyright RightScale, Inc. All rights reserved. All access and use subject to the
# RightScale Terms of Service available at http://www.rightscale.com/terms.php and,
# if applicable, other agreements such as a RightScale Master Subscription Agreement.

rightscale_marker :begin

# Test configurations
actions_to_test = [:create, :attach, :snapshot, :cleanup, :detach, :delete]
# To test the volume creation from a snapshot
snap_id = nil
# To test IOPS on AWS clouds
test_iops = nil

# Set the provider based on the cloud
if node[:cloud][:provider] == 'ec2'
  provider_klass = Chef::Provider::NetworkStorageDeviceEC2
else
  provider_klass = Chef::Provider::NetworkStorageDeviceAPI15
end

Chef::Log.info "  ======= NETWORK STORAGE DEVICE TESTER ========"

Chef::Log.info "  **********************************************"
Chef::Log.info "  ********* Actions: Create & Attach ***********"
Chef::Log.info "  **********************************************"
network_storage_device "test_device" do
  size 10
  description "test block device created inside vagrant"
  snapshot_id snap_id if snap_id
  if test_iops
    options(
      :iops => test_iops
    )
  end
  action [:create, :attach]
  provider provider_klass
  only_if { actions_to_test.include?(:create) && actions_to_test.include?(:attach) }
end

Chef::Log.info "  **********************************************"
Chef::Log.info "  ************* Actions: Snapshot **************"
Chef::Log.info "  **********************************************"
network_storage_device "test_device" do
  action :snapshot
  provider provider_klass
  only_if { actions_to_test.include?(:snapshot) }
end

Chef::Log.info "  **********************************************"
Chef::Log.info "  ************* Actions: Cleanup ***************"
Chef::Log.info "  **********************************************"
network_storage_device "test_device" do
  action :cleanup
  provider provider_klass
  # Ignoring the failure as cleanup action is not supported for EC2 provider
  ignore_failure true if node[:cloud][:provider] == 'ec2'
  only_if { actions_to_test.include?(:cleanup) }
end

Chef::Log.info "  **********************************************"
Chef::Log.info "  ************* Actions: Detach ****************"
Chef::Log.info "  **********************************************"
network_storage_device "test_device" do
  action :detach
  provider provider_klass
  only_if { actions_to_test.include?(:detach) }
end

Chef::Log.info "  **********************************************"
Chef::Log.info "  ************** Actions: Delete ***************"
Chef::Log.info "  **********************************************"
network_storage_device "test_device" do
  action :delete
  provider provider_klass
  only_if { actions_to_test.include?(:delete) }
end

Chef::Log.info "  All actions are executed and finished successfully"

rightscale_marker :end
