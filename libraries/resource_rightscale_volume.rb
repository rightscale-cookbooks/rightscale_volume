#
# Cookbook Name:: rightscale_volume
# Library:: resource_rightscale_volume
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

require 'chef/resource'

class Chef
  class Resource
    # A resource class for 'rightscale_volume' cookbook.
    class RightscaleVolume < Chef::Resource
      # Volume name
      attr_accessor :name

      # Volume ID
      attr_accessor :volume_id

      # Volume size
      attr_accessor :size

      # Volume state
      attr_accessor :state

      # Device to which the volume is attached
      attr_accessor :device

      # Description for the volume
      attr_accessor :description

      # Snapshot ID from which the volume must be created
      attr_accessor :snapshot_id

      # Snapshot name to be created
      attr_accessor :snapshot_name

      # Number of snapshots to retain when running the +:cleanup+ action
      attr_accessor :max_snapshots

      # Timeout value (in minutes) for rightscale_volume actions
      attr_accessor :timeout

      # Initializes rightscale_volume resource.
      #
      # @param name [String] name of the resource.
      # @param run_context [Chef::RunContext] optional value to track context of
      # a chef run.
      # @return [Chef::Resource::RightscaleVolume] the newly created
      # rightscale_volume resource.
      #
      def initialize(name, run_context=nil)
        super
        @resource_name = :rightscale_volume
        @action = "create"
        @allowed_actions.push(:create, :delete, :attach, :detach, :snapshot, :cleanup)
        @provider = Chef::Provider::RightscaleVolume
      end

      # Name of the device.
      #
      # @param arg [String] the volume name
      #
      # @return [String] the volume name
      #
      def name(arg = nil)
        set_or_return(
          :name,
          arg,
          :kind_of => String
        )
      end

      # Size of the device to create in GBs. By default, this is set to 1 GB.
      #
      # @param arg [Integer] the volume size
      #
      # @return [Integer] the volume size
      #
      def size(arg = nil)
        set_or_return(
          :size,
          arg,
          :kind_of => Integer,
          :default => 1
        )
      end

      # Description of the device.
      #
      # @param arg [String] the volume description
      #
      # @return [String] the volume description
      #
      def description(arg = nil)
        set_or_return(
          :description,
          arg,
          :kind_of => String
        )
      end

      # Identifier for a single volume.
      #
      # @param arg [String] the volume ID
      #
      # @return [String] the volume ID
      #
      def volume_id(arg = nil)
        set_or_return(
          :volume_id,
          arg,
          :kind_of => String
        )
      end

      # Name of snapshot.
      #
      # @param arg [String] the snapshot name.
      #
      # @return [String] the snapshot name.
      #
      def snapshot_name(arg = nil)
        set_or_return(
          :snapshot_name,
          arg,
          :kind_of => String
        )
      end

      # Snapshot ID to create the volume from.
      #
      # @param arg [String] the snapshot ID
      #
      # @return [String] snapshot ID
      #
      def snapshot_id(arg = nil)
        set_or_return(
          :snapshot_id,
          arg,
          :kind_of => String
        )
      end

      # Maximum number of snapshots to keep. This is used during cleanup.
      # By default, this is set to 60.
      #
      # @param arg [Integer] the number of snapshots to retain when running the
      # +:cleanup+ action
      #
      # @return [Integer] the number of snapshots to retain
      #
      def max_snapshots(arg = nil)
        set_or_return(
          :max_snapshots,
          arg,
          :kind_of => Integer,
          :default => 60
        )
      end

      # Timeout in minutes. Used to throw an error if the action cannot be
      # completed by the cloud provider within this given minutes. By default,
      # this is set to 15 minutes.
      #
      # @param arg [Integer] the timeout value in minutes for actions
      #
      # @return [Integer] the timeout value
      #
      def timeout(arg = nil)
        set_or_return(
          :timeout,
          arg,
          :kind_of => Integer,
          :default => 15
        )
      end

      # Hash that holds cloud provider specific attributes such as IOPS or
      # volume_type ('SATA'/'SSD').
      #
      # @param arg [Hash] the optional parameters for actions
      #
      # @return [Hash] the optional parameters
      #
      def options(arg = nil)
        set_or_return(
          :options,
          arg,
          :kind_of => Hash,
          :default => {}
        )
      end
    end
  end
end
