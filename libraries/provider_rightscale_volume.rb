#
# Cookbook Name:: rightscale_volume
# Library:: provider_rightscale_volume
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

require "chef/provider"

class Chef
  class Provider
    # A provider class for rightscale_volume cookbook.
    class RightscaleVolume < Chef::Provider

      # Loads @current_resource instance variable with device hash values in the
      # node if device exists in the node. Also initializes platform methods
      # and right_api_client for making API calls.
      #
      def load_current_resource
        @current_resource ||= Chef::Resource::RightscaleVolume.new(@new_resource.name)
        node.set['rightscale_volume'] ||= {}

        @api_client = initialize_api_client

        # If the volume name does not exist in the device hash, it is not probably created
        # or may have been deleted
        unless node['rightscale_volume'][@current_resource.name].nil?
          @current_resource.volume_id = node['rightscale_volume'][@current_resource.name]['volume_id']
          @current_resource.device = node['rightscale_volume'][@current_resource.name]['device']

          # Get the volume details from the API
          volume = find_volumes(:resource_uid => node['rightscale_volume'][@current_resource.name]['volume_id']).first
          if volume.nil?
            delete_device_hash
            raise "Volume '#{node['rightscale_volume'][@current_resource.name]}'" +
              " could not be found in the cloud"
          else
            volume_details = volume.show
            @current_resource.size = volume_details.size.to_i
            @current_resource.description = volume_details.description
            @current_resource.state = volume_details.status
          end
        end
        @current_resource.timeout = @new_resource.timeout if @new_resource.timeout

        @current_resource
      end

      # Creates a new volume with the given name. If snapshot_id is provided,
      # a new volume is created from the snapshot.
      #
      def action_create
        raise "Cannot create a volume with specific ID." if @new_resource.volume_id

        # If volume of the same size already created do nothing. Else raise an exception.
        if @current_resource.state
          if @current_resource.size == @new_resource.size
            msg = "Volume '#{@current_resource.name} (#{@current_resource.size} GB)' already exists.\n"
            msg << "Volume ID: '#{@current_resource.volume_id}'\n" if @current_resource.volume_id
            msg << "Attached to: '#{@current_resource.device}'" if @current_resource.device
            Chef::Log.info msg
            return
          else
            raise "Volume with name '#{@current_resource.name} (#{@current_resource.size} GB)' already exists." +
              " Cannot create another volume of size #{@new_resource.size} GB with the same name!"
          end
        end

        # If snapshot_id is provided restore volume from the specified snapshot.
        if @new_resource.snapshot_id
          Chef::Log.info "Creating a new volume from snapshot '#{@new_resource.snapshot_id}'..."
        else
          Chef::Log.info "Creating a new volume '#{@current_resource.name}'..."
        end
        volume = create_volume(
          @new_resource.name,
          @new_resource.size,
          @new_resource.description,
          @new_resource.snapshot_id,
          @new_resource.options
        )

        if volume.nil?
          raise "Volume '#{@current_resource.name}' was not created successfully!"
        else
          @current_resource.volume_id = volume.resource_uid

          # Store all volume information in node variable
          save_device_hash
          @new_resource.updated_by_last_action(true)
          Chef::Log.info "Volume '#{@current_resource.name}' successfully created"
        end
      end

      # Deletes a volume with the given name.
      #
      def action_delete
        # If volume already deleted, do nothing.
        if @current_resource.state.nil?
          Chef::Log.info "Device '#{@current_resource.name}' does not exist." +
            " This device may have been deleted or never been created."
          return
        elsif @current_resource.state == "in-use"
          error_msg = "Volume is not available for deletion. Volume status: '#{@current_resource.state}'.\n"
          error_msg << "Volume still attached to '#{@current_resource.device}'." unless @current_resource.device.nil?
          error_msg << " Detach the volume using 'detach' action before attempting to delete."
          raise error_msg
        end

        Chef::Log.info "Deleting volume '#{@current_resource.name}'..."
        if delete_volume(@current_resource.volume_id)
          # Set device in node variable to nil after successfully deleting the volume
          delete_device_hash
          @new_resource.updated_by_last_action(true)
          Chef::Log.info " Successfully deleted volume '#{@current_resource.name}'"
        else
          if node['cloud']['provider'] == 'rackspace-ng'
            Chef::Log.info "Volume '#{@current_resource.name}' was not deleted!"
          else
            raise "Volume '#{@current_resource.name}' was not deleted!"
          end
        end
      end

      # Attaches a volume to a device.
      #
      def action_attach
        # If volume is not created or already attached, do nothing
        if @current_resource.state.nil?
          raise "Device '#{@current_resource.name}' does not exist." +
            " This device may have been deleted or never been created."
        elsif @current_resource.state == "in-use"
          msg = "Volume '#{@current_resource.name}' is already attached"
          msg << " to '#{@current_resource.device}'" unless @current_resource.device.nil?
          Chef::Log.info msg
          return
        end

        Chef::Log.info "Attaching volume '#{@current_resource.name}'..."

        @current_resource.device = attach_volume(@current_resource.volume_id, get_next_device(device_letter_exclusions))

        if @current_resource.device.nil?
          raise "Volume '#{@current_resource.name}' was not attached successfully!"
        else
          # Store all information in node variable
          save_device_hash
          @new_resource.updated_by_last_action(true)
          Chef::Log.info "Volume '#{@current_resource.name}' successfully attached to '#{@current_resource.device}'"
        end
      end

      # Detaches a volume from the device.
      #
      def action_detach
        # If volume is not available or not attached, do nothing
        if @current_resource.state.nil?
          raise "Device '#{@current_resource.name}' does not exist." +
            " This device may have been deleted or never been created."
        elsif @current_resource.state != "in-use"
          Chef::Log.info "Volume '#{@current_resource.name}' is not attached."
          Chef::Log.info "Volume status: '#{@current_resource.state}'."
          return
        end

        Chef::Log.info "Detaching volume '#{@current_resource.name}'..."

        if detach_volume(@current_resource.volume_id)
          @current_resource.device = nil

          # Store all information in node variable
          save_device_hash
          @new_resource.updated_by_last_action(true)
          Chef::Log.info "Volume '#{@current_resource.name}' successfully detached."
        else
          raise "Volume '#{@current_resource.name}' was not successfully detached!"
        end
      end

      # Creates a snapshot of the specified volume.
      #
      def action_snapshot
        if @current_resource.state.nil?
          raise "Device '#{@current_resource.name}' does not exist." +
            " This device may have been deleted or never been created."
        end

        Chef::Log.info "Creating snapshot of volume '#{@current_resource.name}'..."

        snapshot_name = @current_resource.name
        snapshot_name = @new_resource.snapshot_name if @new_resource.snapshot_name
        snapshot = create_snapshot(snapshot_name, @current_resource.volume_id)

        if snapshot.nil?
          raise "Snapshot of volume '#{@current_resource.name}' not created successfully!"
        else
          Chef::Log.info "Snapshot of volume '#{@current_resource.name}' successfully created."
          Chef::Log.info "Snapshot name: '#{snapshot.name}', ID: '#{snapshot.resource_uid}'"
        end
      end

      # Deletes old snapshots that exceeds the maximum snapshots limit for the specified volume.
      #
      def action_cleanup
        if @current_resource.state.nil?
          raise "Device '#{@current_resource.name}' does not exist." +
            " This device may have been deleted or never been created."
        end

        # If user provides a value for max_snapshots use that or else use value
        # in the node.
        max_snapshots = @current_resource.max_snapshots
        max_snapshots = @new_resource.max_snapshots if @new_resource.max_snapshots
        num_snaps_deleted = cleanup_snapshots(@current_resource.volume_id, max_snapshots)

        if num_snaps_deleted > 0
          Chef::Log.info "A total of #{num_snaps_deleted} snapshots were deleted."
        else
          Chef::Log.info "No snapshots were deleted."
        end
      end

    private

      # Removes the device hash from the node variable.
      #
      def delete_device_hash
        node.set['rightscale_volume'][@current_resource.name] = nil
      end

      # Saves device hash to the node variable.
      #
      def save_device_hash
        node.set['rightscale_volume'][@current_resource.name] ||= {}
        node.set['rightscale_volume'][@current_resource.name]['volume_id'] = @current_resource.volume_id
        node.set['rightscale_volume'][@current_resource.name]['device'] = @current_resource.device
      end

      # Initializes API client for handling API 1.5 calls.
      #
      # @param options [Hash] the optional parameters to the client
      #
      # @return [RightApi::Client] the RightAPI client instance
      #
      def initialize_api_client(options = {})
        # Require gems in initialize
        require "right_api_client"

        require "/var/spool/cloud/user-data.rb"
        account_id, instance_token = ENV["RS_API_TOKEN"].split(":")
        api_url = "https://#{ENV["RS_SERVER"]}"
        options = {
          :account_id => account_id,
          :instance_token => instance_token,
          :api_url => api_url
        }.merge options

        client = RightApi::Client.new(options)
        client.log(Chef::Log.logger)
        client
      end

      # Creates a new volume.
      #
      # @param name [String] the volume name
      # @param size [Integer] the volume size
      # @param description [String] the volume description
      # @param options [Hash] the optional parameters for creating volume
      #
      # @return [RightApi::ResourceDetail] the created volume
      #
      # @raise [RuntimeError] if volume size is less than 100 GB for Rackspace Open Cloud
      # @raise [RuntimeError] if no snapshots were found in the cloud with the given snapshot ID
      # @raise [RuntimeError] if the volume creation is unsuccessful
      # @raise [Timeout::Error] if volume creation takes longer than the timeout value
      #
      def create_volume(name, size, description = "", snapshot_id = nil, options = {})
        if (size < 100 && node['cloud']['provider'] == "rackspace-ng")
          raise "Minimum volume size supported by this cloud is 100 GB."
        end

        # Set required parameters
        params = {
          :volume => {
            :name => name,
            :size => size.to_s,
          }
        }

        instance = @api_client.get_instance
        datacenter_href = instance.links.detect { |link| link["rel"] == "datacenter" }
        params[:volume][:datacenter_href] = datacenter_href["href"] if datacenter_href

        volume_type_href = get_volume_type_href(node['cloud']['provider'], size, options)
        params[:volume][:volume_type_href] = volume_type_href unless volume_type_href.nil?

        # If description parameter is nil or empty do not pass it to the API
        params[:volume][:description] = description unless (description.nil? || description.empty?)

        # If snapshot_id is provided in the arguments, find the snapshot
        # and create the volume from the snapshot found
        unless snapshot_id.nil?
          snapshot = @api_client.volume_snapshots.index(:filter => ["resource_uid==#{snapshot_id}"]).first
          if snapshot.nil?
            raise "No snapshots found with snapshot ID '#{snapshot_id}'"
          else
            Chef::Log.info "Snapshot found with snapshot ID '#{snapshot_id}'"
            Chef::Log.info "Snapshot name - '#{snapshot.show.name}' Snapshot state - '#{snapshot.show.state}'"
            params[:parent_volume_snapshot_href] = snapshot.href
          end
        end

        Chef::Log.info "Requesting volume creation with params = #{params.inspect}"

        # Create volume and wait until the volume becomes "available" or "provisioned" (in azure)
        created_volume = nil
        Timeout::timeout(@current_resource.timeout * 60) do
          created_volume = @api_client.volumes.create(params)

          # Wait until the volume is successfully created. A volume is said to be created
          # if volume status is "available" or "provisioned" (in Cloudstack and Azure).
          name = created_volume.show.name
          status = created_volume.show.status
          while status != "available" && status != "provisioned"
            Chef::Log.info "Waiting for volume '#{name}' to create... Current status is '#{status}'"
            raise "Creation of volume has failed." if status == "failed"
            sleep 2
            status = created_volume.show.status
          end
        end

        created_volume.show
      end

      # Gets href of a volume_type.
      #
      # @param cloud [Symbol] the cloud which supports volume types
      # @param size [Integer] the volume size (used by CloudStack to select appropriate volume type)
      # @param options [Hash] the optional parameters required to choose volume type
      #
      # @return [String, nil] the volume type href
      #
      # @raise [RuntimeError] if the volume type could not be found for the requested size (on CloudStack)
      #
      def get_volume_type_href(cloud, size, options = {})
        case cloud
        when "rackspace-ng"
          # Rackspace Open Cloud offers two types of devices - SATA and SSD
          volume_types = @api_client.volume_types.index

          # Set SATA as the default volume type for Rackspace Open Cloud
          options[:volume_type] = 'SATA' if options[:volume_type].nil?
          volume_type = volume_types.detect do |type|
            type.name.downcase == options[:volume_type].downcase
          end
          volume_type.href

        when "cloudstack"
          # CloudStack has the concept of a "custom" disk offering
          # Anything that is not a custom type is a fixed size.
          # If there is not a custom type, we will use the closest size which is
          # greater than or equal to the requested size.
          # If there are multiple custom volume types or multiple volume types
          # with the closest size, the one with the greatest resource_uid will
          # be used.
          # If the resource_uid is non-numeric (e.g. a UUID), the first returned
          # valid volume type will be used.
          volume_types = @api_client.volume_types.index
          custom_volume_types = volume_types.select { |type| type.size.to_i == 0 }

          if custom_volume_types.empty?
            volume_types.reject! { |type| type.size.to_i < size }
            minimum_size = volume_types.map { |type| type.size.to_i }.min
            volume_types.reject! { |type| type.size.to_i != minimum_size }
          else
            volume_types = custom_volume_types
          end

          if volume_types.empty?
            raise "Could not find a volume type that is large enough for #{size}"
          elsif volume_types.size == 1
            volume_type = volume_types.first
          elsif volume_types.first.resource_uid =~ /^[0-9]+$/
            Chef::Log.info "Found multiple valid volume types"
            Chef::Log.info "Using the volume type with the greatest numeric resource_uid"
            volume_type = volume_types.max_by { |type| type.resource_uid.to_i }
          else
            Chef::Log.info "Found multiple valid volume types"
            Chef::Log.info "Using the first returned valid volume type"
            volume_type = volume_types.first
          end

          if volume_type.size.to_i == 0
            Chef::Log.info "Found volume type that supports custom sizes:" +
              " #{volume_type.name} (#{volume_type.resource_uid})"
          else
            Chef::Log.info "Did not find volume type that supports custom sizes"
            Chef::Log.info "Using closest volume type: #{volume_type.name}" +
              " (#{volume_type.resource_uid}) which is #{volume_type.size} GB"
          end

          volume_type.href
        end
      end

      # Deletes volume specified by resource UID.
      #
      # @param volume_id [String] the resource UID of the volume to be deleted
      #
      # @result [Boolean] status of volume deletion
      #
      # @raise [RightApi::Exceptions::ApiException] if volume destroy fails
      # @raise [Timeout:Error] if the volume deletion takes longer than the time out value
      #
      def delete_volume(volume_id)
        # Get volume by Resource UID
        volume = find_volumes(:resource_uid => volume_id).first

        # Rescue 422 errors with following error message "Volume still has 'n'
        # dependent snapshots" and add warning statements to indicate volume
        # deletion failure. This is a workaround for Rackspace Open Cloud
        # limitation where a volume cannot be destroyed if it has dependent
        # snapshots.
        Timeout::timeout(@current_resource.timeout * 60) do
          begin
            Chef::Log.info "Performing volume destroy..."
            volume.destroy
          rescue RightApi::Exceptions::ApiException => e
            http_code = e.message.match("HTTP Code: ([0-9]+)")[1]
            if http_code == "422" && e.message =~ /Volume still has \d+ dependent snapshots/
              Chef::Log.warn "#{e.message}. Cannot destroy volume #{volume.show.name}"
              return false
            else
              raise e
            end
          end
        end
        true
      end

      # Attaches a volume to a device.
      #
      # @param volume_id [String] the resource UID of the volume to be attached
      # @param device [String] the device to which the volume must be attached
      #
      # @return [String] the device to which volume actually attached
      #
      # @raise [RestClient::Exception] if volume attachment fails
      # @raise [Timeout:Error] if the volume attach takes longer than the time out value
      #
      def attach_volume(volume_id, device)
        # Get volume that needs to be attached by its resource UID
        volume = find_volumes(:resource_uid => volume_id).first

        # Set required parameters
        params = {
          :volume_attachment => {
            :volume_href => volume.show.href,
            :instance_href => @api_client.get_instance.href,
            :device => device
          }
        }

        # use the lowest available LUN if we are on Azure/HyperV/VirtualPC
        hypervisor = node[:virtualization][:system] || node[:virtualization][:emulator]
        if hypervisor == "virtualpc" || node['cloud']['provider'] == "google"
          luns = attached_devices.map { |attached_device| attached_device.to_i }.to_set
          lun = 0
          params[:volume_attachment][:device] = loop do
            break lun unless luns.include? lun
            lun += 1
          end
        end

        # Grab the list of devices in use before attaching the volume so that
        # we can find the actual device after attachment
        current_devices = get_current_devices

        Chef::Log.info "Requesting volume attachment with params = #{params.inspect}"

        Timeout::timeout(@current_resource.timeout * 60) do
          begin
            attachment = @api_client.volume_attachments.create(params)
          rescue RestClient::Exception => e
            if e.http_code == 504
              Chef::Log.info "Timeout creating attachment - #{e.message}, retrying..."
              sleep 2
              retry
            end
            display_exception(e, "volume_attachments.create(#{params.inspect})")
            raise e
          end

          # Wait for volume to attach and become "in-use"
          begin
            volume_details = volume.show
            volume_status = volume_details.status
            attachment_state = attachment.show.state
            while volume_status != "in-use" && attachment_state != "attached"
              Chef::Log.info "Waiting for volume '#{volume_details.name}' to attach... Status is '#{volume_status}'..."
              Chef::Log.info "Volume attachment state is '#{attachment_state}'"
              sleep 2
              volume_status = volume.show.status
              attachment_state = attachment.show.state
            end
          rescue RestClient::Exception => e
            if e.http_code == 504
              Chef::Log.info "Timeout waiting for attachment - #{e.message}, retrying..."
              sleep 2
              retry
            end
            display_exception(e, e.message)
            raise e
          end
        end

        # Determine the actual device name
        (Set.new(get_current_devices) - current_devices).first
      end

      # Finds volumes using the given filters.
      #
      # @param filters [Hash] the filters to find the volume
      #
      # @return [<RightApi::Client::Resource>Array] the volumes found
      #
      def find_volumes(filters = {})
        @api_client.volumes.index(:filter => build_filters(filters))
      end

      # Builds a filters array in the format required by the RightScale API.
      #
      # @param filters [Hash<String, Object>] the filters as name, filter pairs
      #
      # @return [Array<String>] the filters as strings
      #
      def build_filters(filters)
        filters.map do |name, filter|
          case filter.to_s
          when /^(!|<>)(.*)$/
            operator = "<>"
            filter = $2
          when /^(==)?(.*)$/
            operator = "=="
            filter = $2
          end
          "#{name}#{operator}#{filter}"
        end
      end

      # Gets the devices to which the volumes are attached.
      #
      # @return [Array] devices to which the volumes are attached
      #
      def attached_devices
        volume_attachments.map { |attachment| attachment.show.device }
      end

      # Find the volume attachments on an instance using the given filters.
      #
      # @param filters [Hash] the filters to find volume attachments
      #
      # @return [RightApi::Resources] the volume attachments
      #
      def volume_attachments(filters = {})
        filter = ["instance_href==#{@api_client.get_instance.href}"] + build_filters(filters)
        @api_client.volume_attachments.index(:filter => filter).reject do |attachment|
          attachment.show.device.include? "unknown"
        end
      end

      # Detaches a volume from the device.
      #
      # @param volume_id [String] the resource UID of the volume to be detached
      #
      # @return [Boolean] true if volume detached successfully
      #
      # @raise [Timeout::Error] if detaching volumes take longer than the time out value
      #
      def detach_volume(volume_id)
        # Using the resource ID of the volume to be detached find its corresponding
        # volume attachment using the API
        volume = find_volumes(:resource_uid => volume_id).first
        attachments = volume_attachments(:volume_href => volume.href)

        attachments.map do |attachment|
          volume = attachment.volume
          volume_details = volume.show
          Chef::Log.info "Volume #{volume_details.name} is '#{volume_details.status}'"
          Chef::Log.info "Performing volume detach..."
          Timeout::timeout(@current_resource.timeout * 60) do
            attachment.destroy
            while (volume_status = volume.show.status) == "in-use"
              Chef::Log.info "Waiting for volume '#{volume_details.name}' to detach. Status is '#{volume_status}'..."
              sleep 2
            end
          end
          volume
        end
        true
      end

      # Creates a snapshot of a given volume.
      #
      # @param snapshot_name [String] the name of the snapshot to be created
      # @param volume_id [String] the resource UID of the volume
      #
      # @return [RightApi::ResourceDetail] the snapshot created from the volume
      #
      # @raise [RuntimeError] if snapshot creation failed
      # @raise [Timeout::Error] if snapshot creation takes longer than the time out value
      #
      def create_snapshot(snapshot_name, volume_id)
        volume = find_volumes(:resource_uid => volume_id).first
        params = {
          :volume_snapshot => {
            :name => snapshot_name,
            :description => volume.show.description,
            :parent_volume_href => volume.href
          }
        }

        Chef::Log.info "Performing volume snapshot..."
        snapshot = nil
        Timeout::timeout(@current_resource.timeout * 60) do
          snapshot = @api_client.volume_snapshots.create(params)
          name = snapshot.show.name
          while ((state = snapshot.show.state) == "pending")
            Chef::Log.info "Waiting for snapshot '#{name}' to create... State is '#{state}'"
            raise "Snapshot creation failed!" if state == "failed"
            sleep 2
          end
        end
        snapshot.show
      end

      # Gets all snapshots taken from the given volume.
      #
      # @param volume_id [String] the resource UID of the volume
      #
      # @return [<RightApi::Resource>Array] the list of snapshots
      #
      def get_snapshots(volume_id)
        volume = find_volumes(:resource_uid => volume_id).first
        @api_client.volume_snapshots.index(:filter => ["parent_volume_href==#{volume.href}"])
      end

      # Deletes old snapshots of a specified volume that exceeds the maximum number of snapshots
      # to keep for that volume.
      #
      # @param volume_id [String] the resource UID of the volume
      # @param max_snapshots_to_keep [Integer] the maximum number of snapshots to keep for a volume
      #
      # @return [Integer] the number of snapshots actually deleted
      #
      # @raise [Timeout::Error] if snapshot deletion takes longer than the time out value
      #
      def cleanup_snapshots(volume_id, max_snapshots_to_keep)
        available_snapshots = get_snapshots(volume_id)

        # Sort the snapshots found from oldest to latest
        available_snapshots = available_snapshots.sort_by { |snapshot| snapshot.show.updated_at }

        num_deleted = 0
        num_available_snapshots = available_snapshots.length
        # If number of available snapshots less than or equal to maximum number
        # of snapshots to keep, no need to delete any snapshot.
        # Else, delete the oldest snapshots that exceeds maximum number of
        # snapshots to keep.
        if num_available_snapshots <= max_snapshots_to_keep
          Chef::Log.info "Number of available snapshots (#{num_available_snapshots}) is less than or equal to maximum" +
            " number of snapshots to keep (#{max_snapshots_to_keep})."
          Chef::Log.info "No snapshots were deleted."

        else
          num_snapshots_to_delete = num_available_snapshots - max_snapshots_to_keep

          Chef::Log.info "Performing snapshot cleanup..."
          available_snapshots.each do |snapshot|
            # End condition for this loop
            break if num_deleted == num_snapshots_to_delete

            snapshot_details = snapshot.show
            # Skip over snapshots that are not available for deletion.
            if snapshot_details.state == "pending"
              Chef::Log.info "Snapshot #{snapshot_details.name} (ID:#{snapshot_details.resource_uid})" +
                " is not available for deletion. Snapshot state is '#{snapshot_details.state}'"
              next
            end

            # Delete snapshot if they are available
            Chef::Log.info "Deleting snapshot '#{snapshot_details.name} (ID: #{snapshot_details.resource_uid})'..."
            Timeout::timeout(@current_resource.timeout * 60) do
              snapshot.destroy
            end
            num_deleted = num_deleted + 1
          end
        end
        num_deleted
      end

      # Attempts to display any http response related information about the
      # exception and simply inspect the exception if none is available.
      #
      # @param e [Exception] the exception which needs to displayed and inspected.
      # @param display_name [String] optional display name to print custom information.
      #
      def display_exception(e, display_name = nil)
        Chef::Log.info "CAUGHT EXCEPTION in: #{display_name}"
        Chef::Log.info e.inspect
        puts e.backtrace
        if e.respond_to?(:response)
          Chef::Log.info e.response
          if e.response.respond_to?(:body)
            Chef::Log.info "RESPONSE BODY: #{e.response.body}"
          end
        end
      end

      # Gets all supported devices from /proc/partitions.
      #
      # @return [Array] the devices list.
      #
      def get_current_devices
        # Read devices that are currently in use from the last column in /proc/partitions
        partitions = IO.readlines("/proc/partitions").drop(2).map { |line| line.chomp.split.last }

        # Eliminate all LVM partitions
        partitions = partitions.reject { |partition| partition =~ /^dm-\d/ }

        # Get all the devices in the form of sda, xvda, hda, etc.
        devices = partitions.select { |partition| partition =~ /[a-z]$/ }.sort.map { |device| "/dev/#{device}" }

        # If no devices found in those forms, check for devices in the form of sda1, xvda1, hda1, etc.
        if devices.empty?
          devices = partitions.select { |partition| partition =~ /[0-9]$/ }.sort.map { |device| "/dev/#{device}" }
        end

        devices
      end

      # Obtains the next available device.
      #
      # @param exclusions [Array] the devices to exclude
      #
      # @return [String] the available device
      #
      # @raise [RuntimeError] if the partition is unknown
      #
      def get_next_device(exclusions = [])
        # Get the list of currently used devices
        partitions = get_current_devices

        # The AWS EBS documentation recommends using /dev/sd[f-p] for attaching volumes.
        #
        # http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-attaching-volume.html
        #
        if node['cloud']['provider'] == "ec2" && partitions.last =~ /^\/dev\/(s|xv)d[a-d][0-9]*$/
          partitions << "/dev/#{$1}de"
        end

        # The current devices are in the form of sda, hda, xvda, etc.
        if partitions.first =~ /^\/dev\/([a-z]+d)[a-z]+$/
          device_type = $1

          # Get the device letter of the last device in the list of current devices
          partitions.select do |partition|
            partition =~ /^\/dev\/#{device_type}[a-z]+$/
          end.last =~ /^\/dev\/#{device_type}([a-z]+)$/

          last_device_letter_in_use = $1

          if node['cloud']['provider'] == 'ec2' && device_type == 'hd'
            # This is probably HVM
            hvm = true
            # Root device is /dev/hda on HVM images, but volumes are xvd in /proc/partitions,
            # but can be referenced as sd also (mount shows sd) - PS
            device_type.sub!('hd','xvd')
          end

          # This is a HVM image, need to start at xvdf at least
          letters = hvm ? (['e', last_device_letter_in_use].max .. 'zzz') : (last_device_letter_in_use .. 'zzz')

          # Get the device letter next to the last device letter in use
          device_letter = letters.select { |letter| letter != letters.first && !exclusions.include?(letter) }.first

        # The current devices are in the form sda1, xvdb1, etc.
        elsif partitions.first =~ /^\/dev\/([a-z]+d[a-z]*)\d+$/
          device_type = $1

          partitions.select do |partition|
            partition =~ /^\/dev\/#{device_type}\d+$/
          end.last =~ /^\/dev\/#{device_type}(\d+)$/

          last_device_letter_in_use = $1.to_i

          # Get the device letter (number in this case) next to the last device letter in use
          device_letter = last_device_letter_in_use + 1
        else
          raise "unknown partition/device name: #{partitions.first}"
        end

        "/dev/#{device_type}#{device_letter}"
      end

      # Returns a list of device exclusions due to some hypervisors having "holes" in their attachable device list.
      #
      # @return [Array] the device exclusions
      #
      def device_letter_exclusions
        exclusions = []
        # /dev/xvdd is assigned to the cdrom device eg., xentools iso (xe-guest-utilities)
        # that is likely a xenserver-ism
        exclusions = ['d'] if node['cloud']['provider'] == 'cloudstack'
        exclusions
      end

      # Scans for volume attachments.
      #
      def scan_for_attachments
        # vmware/esx requires the following "hack" to make OS/Linux aware of device
        # Check for /sys/class/scsi_host/host0/scan if need to run
        if ::File.exist?('/sys/class/scsi_host/host0/scan')
          cmd = Mixlib::ShellOut.new("echo '- - -' > /sys/class/scsi_host/host0/scan")
          cmd.run_command
          sleep 5
        end
      end
    end
  end
end
