#
# Cookbook Name:: rightscale_volume
# Library:: matchers
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

if defined?(ChefSpec)
  def create_rightscale_volume(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new('rightscale_volume', :create, resource_name)
  end

  def attach_rightscale_volume(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new('rightscale_volume', :attach, resource_name)
  end

  def detach_rightscale_volume(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new('rightscale_volume', :detach, resource_name)
  end

  def delete_rightscale_volume(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new('rightscale_volume', :delete, resource_name)
  end

  def snapshot_rightscale_volume(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new('rightscale_volume', :snapshot, resource_name)
  end

  def cleanup_rightscale_volume(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new('rightscale_volume', :cleanup, resource_name)
  end
end
