# rightscale_volume cookbook

[![Cookbook](https://img.shields.io/cookbook/v/rightscale_volume.svg?style=flat)][cookbook]
[![Release](https://img.shields.io/github/release/rightscale-cookbooks/rightscale_volume.svg?style=flat)][release]
[![Build Status](https://img.shields.io/travis/rightscale-cookbooks/rightscale_volume.svg?style=flat)][travis]

[cookbook]: https://supermarket.getchef.com/cookbooks/rightscale_volume
[release]: https://github.com/rightscale-cookbooks/rightscale_volume/releases/latest
[travis]: https://travis-ci.org/rightscale-cookbooks/rightscale_volume

# Description

This cookbook provides a rightscale_volume resource that can create, attach and manage a single
block level storage "volume" on numerous public and private IaaS clouds.

A volume provides a highly reliable, efficient storage solution that can be mounted to a
cloud server (within the same datacenter / zone) and persists independently from the life of the instance.

By using the RightScale API, this resource gives your recipes cloud portability without the need
to store your cloud credentials on each server.

Github Repository: [https://github.com/rightscale-cookbooks/rightscale_volume](https://github.com/rightscale-cookbooks/rightscale_volume)

# Requirements

* The system being configured must be a RightScale managed VM to have the required access to the RightScale API.
* Chef 11.
* [RightLink 10](http://docs.rightscale.com/rl10/) See cookbook version 1.2.6 for RightLink 6 support
* Also requires a RightScale account that is registered with all the cloud vendors
  you expect to provision on (e.g. AWS, Rackspace, Openstack, CloudStack, GCE, and Azure).


# Usage

The resource only handles manipulating the volume. Additional resources need to be created in
the recipe to manage the attached volume as a filesystem or logical volume.

The following example will create a 10 GB volume, attach it to the instance, formats the device as ext4
and mounts it to '/mnt/storage'.

```ruby
# Creates a 10 GB volume
rightscale_volume "db_data_volume" do
  size 10
  action :create
end

# Attaches the volume to the instance
rightscale_volume "db_data_volume" do
  action :attach
end

execute "format volume as ext4" do
  command lazy { "mkfs.ext4 #{node['rightscale_volume']['db_data_volume']['device']}" }
  action :run
end

execute "mount volume to /mnt/storage" do
  command lazy { "mkdir -p /mnt/storage; mount #{node['rightscale_volume']['db_data_volume']['device']} /mnt/storage" }
  action :run
end
```

The following example will create a new volume from a snapshot.

```ruby
rightscale_volume "db_data_volume_from_snapshot" do
  size 10
  snapshot_id "my-snaphot-id"
  action [ :create, :attach ]
end
```

The `size` may or may not be honored depending on hypervisor used by the cloud vendor.
If the cloud does not support resize when creating a volume from a snapshot, then the size will be
the same as the volume from which the snapshot was taken. If resize is supported, additional
resources will be required to resize the filesystem on the volume.


# Recipes

## default

The default recipe installs the `right_api_client` RubyGem, which this cookbook requires in
order to work with the RightScale API.


# Resource/Providers

## rightscale_volume

A resource to create, attach, and manage a single "volume" on public and private IaaS clouds.

### Actions

| Name | Description | Default |
| --- | --- | --- |
| `:create` | Creates a new volume in the cloud | yes |
| `:attach` | Attaches a volume to a RightScale server | |
| `:snapshot` | Takes a snapshot of a volume | |
| `:detach` | Detaches a volume from a RightScale server | |
| `:delete` | Deletes a volume from the cloud | |
| `:cleanup` | Cleans up old snapshots of a volume | |

### Attributes

| Name | Description | Default | Required |
| --- | --- | --- | --- |
| `nickname` | Name of the volume to be created | | No |
| `size` | Volume size in gigabytes | `1` | No |
| `description` | Description for the volume | | No |
| `snapshot_id` | Snapshot ID to create the volume from | | No |
| `options` | Optional parameters hash for volume creation. For example, `:volume_type` on Rackspace Open Clouds and `:iops` on AWS clouds | `{}` | No |
| `timeout` | Throws an error if an action could not be completed within this timeout (in minutes) | `15` | No |
| `max_snapshots` | The number of snapshots of a volume to retain when running the `:cleanup` action | `60` | No |


# Cloud Specific Notes

## AWS EC2

* For this resource to work on a EC2 cloud, the RightScale account must be on a
  [UCP](http://support.rightscale.com/12-Guides/Dashboard_Users_Guide/Unified_Cloud_Platform) cluster.
* This cloud supports creating volumes with provisioned IOPS. To create a volume with IOPS on EC2
  pass the `:iops` option to the `options` hash as shown below

```ruby
rightscale_volume "volume_with_iops" do
  size 10
  options {:iops => 100}
  action :create
end
```

## Rackspace Open Cloud

* The minimum volume size offered by this cloud is 100 GB. The `:create` volume action throws an
  error if the requested volume size is lesser than the minimum size offered.
* This cloud supports two types of volume - SATA and SSD. The type of volume to be created can be
  passed to the `options` parameter as below (defaults to SATA if none specified)

```ruby
rightscale_volume "open_cloud_volume" do
  size 100
  options {:volume_type => 'SSD'}
  action :create
end
```
* A volume cannot be deleted from this cloud if at least one snapshot created from this volume
  exists. To delete such a volume, all dependent snapshots must be cleaned up first. The `:delete`
  action does not delete such a volume and throws a warning message in the logs.

## CloudStack Clouds

* CloudStack has the concept of a "custom" disk offering. If a "custom volume type" is supported in the cloud,
  then the `:create` action creates a volume with the requested size. If "custom volume type" is not supported
  then this action will use the "closest volume type" with size greater than or equal to the requested size.
  If there are multiple custom volume types or multiple volume types with the closest size, the one with the greatest
  resource UID will be used.

# Author

Author:: RightScale, Inc. (<cookbooks@rightscale.com>)
