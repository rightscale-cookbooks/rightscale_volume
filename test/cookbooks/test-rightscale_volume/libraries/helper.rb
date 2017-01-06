#
# Cookbook Name:: test-rightscale_volume
# Library:: helper
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

require 'mixlib/shellout'

# A collection of helper methods for testing `rightscale_volume` cookbook.
#
module RightscaleVolumeTest
  module Helper
    MOUNT_POINT = '/mnt/storage'.freeze

    # Initializes `right_api_client`.
    #
    # @return [RightApi::Client] the client instance
    #
    def initialize_api_client
      require 'right_api_client'
      require '/var/spool/cloud/user-data.rb'

      account_id, instance_token = ENV['RS_API_TOKEN'].split(':')
      api_url = "https://#{ENV['RS_SERVER']}"
      client = RightApi::Client.new(account_id: account_id,
                                    instance_token: instance_token,
                                    api_url: api_url)
      client.log(Chef::Log.logger)
      client
    end

    # Gets the instance of the right_api_client if the client is initialized.
    # If client not initialized, this will initialize the client and return the instance.
    #
    # @return [RightApi::Client] the client instance
    #
    def api_client
      @api_client ||= initialize_api_client
    end

    # Checks if the volume is created in the cloud using API calls.
    #
    # @param volume_id [String] the ID of the volume to be queried
    #
    # @return [Boolean] true if volume exists, false otherwise
    #
    def is_volume_created?(volume_id)
      get_volumes(resource_uid: volume_id).empty? ? false : true
    end

    # Gets the list of volumes from the cloud based on the filter.
    #
    # @param filter [Hash] the optional filter to query volumes
    # @see [Volume Resource](http://reference.rightscale.com/api1.5/resources/ResourceVolumes.html#index_filters)
    # for available filters
    #
    # @return [Array<RightApi::Resource>] the volumes found
    #
    def get_volumes(filter = {})
      api_client.volumes.index(filter: build_filters(filter))
    end

    # Checks if the volume is attached to an instance in the cloud.
    #
    # @param volume_id [String] the ID of the volume to be queried
    #
    # @return [Boolean] true if the volume is attached, false otherwise
    #
    def is_volume_attached?(volume_id)
      volume_to_be_attached = get_volumes(resource_uid: volume_id).first
      return false if volume_to_be_attached.nil?
      filter = build_filters(instance_href: api_client.get_instance.href,
                             volume_href: volume_to_be_attached.href)
      api_client.volume_attachments.index(filter: filter).empty? ? false : true
    end

    # Checks if the volume is detached from an instance in the cloud.
    #
    # @param volume_id [String] the ID of the volume to be queried
    #
    # @return [Boolean] true if the volume is detached, false otherwise
    #
    def is_volume_detached?(volume_id)
      volume_to_be_detached = get_volumes(resource_uid: volume_id).first
      return false if volume_to_be_detached.nil?
      filter = build_filters(instance_href: api_client.get_instance.href,
                             volume_href: volume_to_be_detached.href)
      api_client.volume_attachments.index(filter: filter).empty? ? true : false
    end

    # Checks if the volume is deleted from the cloud.
    #
    # @param volume_id [String] the ID of the volume to be queried
    #
    # @return [Boolean] true if the volume is deleted, false otherwise
    #
    def is_volume_deleted?(volume_name)
      volumes_found = get_volumes(name: volume_name)
      volumes_found.empty? ? true : false
    end

    # Checks if the snapshot is created from the volume in the cloud.
    #
    # @param volume_id [String] the ID of the volume to be queried
    #
    # @return [Boolean] true if the snapshot is created, false otherwise
    #
    def is_snapshot_created?(volume_id)
      snapshots_found = get_snapshots(volume_id)
      (snapshots_found.empty? || snapshots_found.nil?) ? false : true
    end

    # Checks if the snapshots of a volume are cleaned up in the cloud.
    #
    # @param volume_id [String] the ID of the volume to be queried
    #
    # @return [Boolean] true if the snapshots are cleaned up, false otherwise
    #
    def is_snapshots_cleaned_up?(volume_id)
      snapshots_found = get_snapshots(volume_id)
      (snapshots_found.nil? || !snapshots_found.empty?) ? false : true
    end

    # Gets the snapshots of a volume in the cloud.
    #
    # @param volume_id [String] the ID of the volume to be queried
    #
    # @return [Array<RightApi::Resource>] the snapshots found
    #
    def get_snapshots(volume_id)
      volume = get_volumes(resource_uid: volume_id).first
      return nil if volume.nil?
      api_client.volume_snapshots.index(filter: build_filters(parent_volume_href: volume.href))
    end

    # Builds filters in the format supported by API 1.5.
    #
    # @param filters [Hash] the filters
    #
    # @return [Array] the array of filters in the supported format
    #
    def build_filters(filters)
      filters.map do |name, filter|
        case filter.to_s
        when /^(!|<>)(.*)$/
          operator = '<>'
          filter = Regexp.last_match(2)
        when /^(==)?(.*)$/
          operator = '=='
          filter = Regexp.last_match(2)
        end
        "#{name}#{operator}#{filter}"
      end
    end

    # Formats the device as ext3 and mounts it to a mount point.
    #
    # @param device [String] the device to be formatted and mounted
    #
    def format_and_mount_device(device)
      Chef::Log.info "Formatting #{device} as ext3..."
      execute_command("mkfs.ext3 -F #{device}")

      Chef::Log.info "Mounting #{device} at #{MOUNT_POINT}..."
      execute_command("mkdir -p #{MOUNT_POINT}")
      execute_command("mount #{device} #{MOUNT_POINT}")
    end

    # Unmounts device from the mount point.
    #
    # @param device [String] the device to be unmounted
    #
    def unmount_device(device)
      Chef::Log.info "Unmounting #{device} from #{MOUNT_POINT}"
      execute_command("umount #{MOUNT_POINT}")
    end

    # Generates a random test file.
    #
    def generate_test_file
      test_file = MOUNT_POINT + '/test_file'
      Chef::Log.info "Generating random file into #{test_file}..."
      execute_command("dd if=/dev/urandom of=#{test_file} bs=16M count=8")
    end

    # Executes the given command.
    #
    # @param command [String] the command to be executed
    #
    def execute_command(command)
      command = Mixlib::ShellOut.new(command)
      command.run_command
      command.error!
    end
  end
end
