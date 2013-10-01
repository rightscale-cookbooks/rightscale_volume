# rightscale_volume cookbook

# Description

This cookbook provides libraries, resources and providers to configure and manage
network storage devices provided by numerous IaaS cloud vendors through RightScale.

A rightscale_volume provides a highly reliable, efficient and persistent storage solution
that can be mounted to a cloud instance (in the same datacenter / zone). It uses
RightScale API calls to manage volumes for VMs running on different cloud vendors.


# Requirements

* The system being configured must be a RightScale managed VM to have the required access to the RightScale API.

* Chef 10 or higher.

* Also requires a RightScale account that is registered with all the cloud vendors
  you expect to provision on (e.g. AWS, Rackspace, Openstack, CloudStack, etc).


# Usage

The resource only handles manipulating the volume, additional resources need to be created in
the recipe to manage the attached volume as a filesystem or logical volume.

The following example will create a 10G volume and attach it to the instance.

```ruby
rightscale_volume "db_data_volume" do
  size 10
  action [ :create, :attach ]
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


# Recipes

## default

The default recipe installs the `right_api_client` RubyGem, which this cookbook requires in
order to work with the RightScale API.


# Actions

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
  </tr>
  <tr>
    <td><tt>create</tt></td>
    <td>Allocates a new volume. Default action</td>
  </tr>
  <tr>
    <td><tt>delete</tt></td>
    <td>Deallocates available volume</td>
  </tr>
  <tr>
    <td><tt>attach</tt></td>
    <td>Attach the volume to the instance</td>
  </tr>
  <tr>
    <td><tt>detach</tt></td>
    <td>Detach the volume from the instance</td>
  </tr>
  <tr>
    <td><tt>snapshot</tt></td>
    <td>Create a snapshot of the volume</td>
  </tr>
  <tr>
    <td><tt>cleanup</tt></td>
    <td>Deletes the oldest snapshots if there are more than `max_snapshots`</td>
  </tr>
</table>


# Attributes

<table>
  <tr>
    <th>Name</th>
    <th>Description</th>
    <th>Default</th>
  </tr>
  <tr>
    <td><tt>node['rightscale_volume']['name']</tt></td>
    <td>Name of the volume</td>
  </tr>
  <tr>
    <td><tt>node['rightscale_volume']['size']</tt></td>
    <td>Volume size in gigabytes</td>
    <td><tt>1</tt></td>
  </tr>
  <tr>
    <td><tt>node['rightscale_volume']['description']</tt></td>
    <td>Description for the volume</td>
  </tr>
  <tr>
    <td><tt>node['rightscale_volume']['volume_id']</tt></td>
    <td>Identifier for a single volume</td>
  </tr>
  <tr>
    <td><tt>node['rightscale_volume']['snapshot_id']</tt></td>
    <td>Snapshot ID to create the volume from</td>
  </tr>
  <tr>
    <td><tt>node['rightscale_volume']['max_snapshots']</tt></td>
    <td>The number of snapshots of a volume to retain when running the :cleanup action</td>
    <td><tt>60</tt></td>
  </tr>
  <tr>
    <td><tt>node['rightscale_volume']['timeout']</tt></td>
    <td>Throws an error if action cannot be completed by the cloud provider within this timeout given in minutes</td>
    <td><tt>15</tt></td>
  </tr>
</table>


# Author

Author:: RightScale, Inc. (<cookbooks@rightscale.com>)
