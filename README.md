# rightscale_volume cookbook

[![Build Status](https://travis-ci.org/rightscale-cookbooks/rightscale_volume.png?branch=master)](https://travis-ci.org/rightscale-cookbooks/rightscale_volume)

# Description

This cookbook provides a rightscale_volume resource that can create, attach and manage a single
block level storage "volume" on numerous public and private IaaS clouds.

A volume provides a highly reliable, efficient storage solution that can be mounted to a
cloud server (within the same datacenter / zone) and persists independently from the life of the instance.

By using the RightScale API, this resource gives your recipes cloud portability without the need
to store your cloud credentials on each server.

# Requirements

* The system being configured must be a RightScale managed VM to have the required access to the RightScale API.

* Chef 10 or higher.

* Also requires a RightScale account that is registered with all the cloud vendors
  you expect to provision on (e.g. AWS, Rackspace, Openstack, CloudStack, GCE, and Azure).


# Recipes

## default

The default recipe installs the `right_api_client` RubyGem, which this cookbook requires in
order to work with the RightScale API.


# Resource/Providers

## rightscale_volume

A resource to create, attach and manage a single "volume" on public and private IaaS clouds.


### Action: create

Creates a new volume in the cloud. This is the default action.

#### Parameters

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>name</td>
    <td>Name of the volume to be created</td>
    <td></td>
  </tr>
  <tr>
    <td>size</td>
    <td>Volume size in gigabytes</td>
    <td>1</td>
  </tr>
  <tr>
    <td>description</td>
    <td>Description for the volume</td>
    <td></td>
  </tr>
  <tr>
    <td>snapshot_id</td>
    <td>Snapshot ID to create the volume from</td>
    <td></td>
  </tr>
  <tr>
    <td>options</td>
    <td>Optional parameters hash for volume creation. For example, <tt>+:volume_type+</tt> on Rackspace Open Clouds
        and <tt>+:iops+</tt> on AWS clouds</td>
    <td>{}</td>
  </tr>
  <tr>
    <td>timeout</td>
    <td>Throws an error if the volume could not be created by the cloud provider within this timeout (in minutes)</td>
    <td>15</td>
  </tr>
</table>

### Action: attach

Attaches a volume to a RightScale server.

#### Parameters

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>name</td>
    <td>Name of the volume to be attached</td>
    <td></td>
  </tr>
  <tr>
    <td>timeout</td>
    <td>Throws an error if the volume could not be attached to the server within this timeout (in minutes)</td>
    <td>15</td>
  </tr>
</table>

### Action: detach

Detaches a volume from a RightScale server.

#### Parameters

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>name</td>
    <td>Name of the volume</td>
    <td></td>
  </tr>
  <tr>
    <td>timeout</td>
    <td>Throws an error if volume could not be detached from the server within this timeout (in minutes)</td>
    <td>15</td>
  </tr>
</table>

### Action: delete

Deletes a volume from the cloud.

#### Parameters

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>name</td>
    <td>Name of the volume</td>
    <td></td>
  </tr>
  <tr>
    <td>timeout</td>
    <td>Throws an error if volume could not be deleted by the cloud provider within this timeout (in minutes)</td>
    <td>15</td>
  </tr>
</table>

### Action: snapshot

Takes a snapshot of a volume.

#### Parameters
<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>name</td>
    <td>Name of the volume</td>
    <td></td>
  </tr>
  <tr>
    <td>timeout</td>
    <td>Throws an error if the snapshot could not be taken  by the cloud provider within this timeout (in minutes)</td>
    <td>15</td>
  </tr>
</table>

### Action: cleanup

Cleans up old snapshots of a volume.

#### Parameters

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td>name</td>
    <td>Name of the volume</td>
    <td></td>
  </tr>
  <tr>
    <td>max_snapshots</td>
    <td>The number of snapshots of a volume to retain when running the <tt>+:cleanup+</tt> action</td>
    <td>60</td>
  </tr>
  <tr>
    <td>timeout</td>
    <td>Throws an error if snapshots could not be cleaned up in the cloud within this timeout (in minutes)</td>
    <td>15</td>
  </tr>
</table>


# Usage

The resource only handles manipulating the volume. Additional resources need to be created in
the recipe to manage the attached volume as a filesystem or logical volume.

The following example will create a 10G volume, attach it to the instance, formats the device as ext4
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
  command "mkfs.ext4 #{node['rightscale_volume']['db_data_volume']['device']}"
  action :run
end

execute "mount volume to /mnt/storage" do
  command "mkdir -p /mnt/storage; mount #{node['rightscale_volume']['db_data_volume']['device']} /mnt/storage"
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

The `size` may or may not be honored (depending on hypervisor used by the cloud vendor).
If the cloud does not support resize when creating a volume from a snapshot, then the size will be
the same as the volume from which the snapshot was taken. If resize is supported, additional
resources will be required to resize the filesystem on the volume.


# Cloud Specific Notes

## AWS EC2

* For this resource to work on a EC2 cloud, the RightScale account must be on a
  [UCP](http://support.rightscale.com/12-Guides/Dashboard_Users_Guide/Unified_Cloud_Platform) cluster.

## Rackspace Open Cloud

* The minimum volume size offered by this cloud is 100 GB. The `+:create+` volume action throws an
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
* A volume cannot be deleted from this cloud, if it has at least one dependent snapshot(s)
  i.e., snapshots created from this volume. To delete such a volume, all dependent snapshots must be
  cleaned up first. The `+:delete+` action does not delete such a volume and throws a warning message in the logs.

## CloudStack Clouds

* CloudStack has the concept of a "custom" disk offering. If a "custom volume type" is supported in the cloud,
  then the `+:create+` action creates a volume with the requested size. If "custom volume type" is not supported
  then this action will use the "closest volume type" with size greater than or equal to the requested size.
  If there are multiple custom volume types or multiple volume types with the closest size, the one with the greatest
  resource UID will be used.

# Author

Author:: RightScale, Inc. (<cookbooks@rightscale.com>)
