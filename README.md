# rightscale_volume cookbook

## Description

This cookbook provides libraries, resources and providers to configure and manage
network storage devices provided by numerous IaaS cloud vendors.

A rightscale_volume provides a highly reliable, efficient and
persistent storage solution that can be mounted to a cloud instance
(in the same datacenter / zone). It uses the RightScale API calls, and so, have the
ability to manage volumes for VMs running on a large array of different cloud
vendors. No cloud credentials are required if running on a RightScale managed
instance.


## Requirements

* The system being configured must be a RightScale managed VM to have the required access to the RightScale API.

* Chef 0.10+ is recommended.

* Also requires a RightScale account that is registered with all the cloud vendors
  you expect to provision on (e.g. AWS, Rackspace, Openstack, CloudStack, etc).


## Usage

The resource only handles manipulating the volume, additional resources need to be created in
the recipe to manage the attached volume as a filesystem or logical volume.

The following example will create a 10G volume and attach it to the instance.

    rightscale_volume "db_data_volume" do
      size 10
      action [ :create, :attach ]
    end

The following example will create a new volume from a snapshot.

    rightscale_volume "db_data_volume_from_snapshot" do
      size 10
      snapshot_id "my-snaphot-id"
      action [ :create, :attach ]
    end

The `size` may or may not be honored (depending on hypervisor used by the cloud vendor).
If the cloud does not support resize when creating a volume from a snapshot, then the size will be
the same as the volume from which the snapshot was taken. If resize is supported, additional
resources will be required to resize the filesystem on the volume.

## Recipes

### default

The default recipe installs the `right_api_client` RubyGem, which this cookbook requires in
order to work with the RightScale API. It also installs other required gems required for making the API calls.

## Supported Actions

* `create` - allocates a new volume. (default)
* `delete` - deallocates available volume
* `attach` - attach the volume to the instance
* `detach` - detach the volume from the instance
* `snapshot` - create a snapshot of the volume
* `cleanup`  - deletes the oldest snapshots if there are more than `max_snapshots`

## Cookbook Attributes

* `name` - name of the volume  Default: Name attribute.
* `size` - volume size in gigabytes. Default: 1.
* `description` - the description for the volume or snapshot during the :create or
   :snapshot action (respectively).
* `volume_id` - the volume to attach. Useful if the volume was created outside this
   node. Cannot be specified for :create action.
* `snapshot_id` - the snapshot to create the volume from.
* `max_snapshots` - the number of snapshots to retain when running the :cleanup action.
   Default: 60.
* `timeout` - throws an error if action cannot be completed by the cloud provider within
   this timeout given in minutes. Default: 15.


## License

Copyright RightScale, Inc. All rights reserved.  All access and use subject to
the RightScale Terms of Service available at http://www.rightscale.com/terms.php
and, if applicable, other agreements such as a RightScale Master Subscription
Agreement.
