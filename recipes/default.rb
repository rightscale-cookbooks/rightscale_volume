#
# Cookbook Name:: rightscale_volume
# Recipe:: default
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

log 'Installing required gems and dependencies...'

# Install build-essentials at compile time so it is available for right_api_client
node.normal['build-essential']['compile_time'] = true
include_recipe 'build-essential'

# Install gems during compile phase so that they are available to files
# which require them during converge phase.
chef_gem 'right_api_client'
