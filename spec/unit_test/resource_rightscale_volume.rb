#
# Cookbook Name:: rightscale_volume
# Spec:: resource_rightscale_volume
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

require 'spec_helper'

describe Chef::Resource::RightscaleVolume do
  let(:resource) { Chef::Resource::RightscaleVolume.new('rightscale_volume', run_context) }
  let(:node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  it { resource.resource_name.should == :rightscale_volume }
  it { resource.size.should == 1 }
  it { resource.max_snapshots == 60 }
  it { resource.timeout == 15 }

  context "attributes that can be set" do
    it "has a name attribute to set the name for the volume" do
      resource.name('test_volume')
      resource.name.should == 'test_volume'
    end

    it "has a size attribute to set the size for the volume" do
      resource.size(10)
      resource.size.should == 10
    end

    it "has a size attribute which takes only integer values" do
      expect { resource.size('10') }.to raise_error
    end

    it "has a volume_id attribute to find a volume by its ID" do
      resource.volume_id('some_id')
      resource.volume_id.should == 'some_id'
    end

    it "has a snapshot_name attribute to set the name for the snapshot" do
      resource.snapshot_name('some_name')
      resource.snapshot_name.should == 'some_name'
    end

    it "has a snapshot_id attribute to find a snapshot by its ID" do
      resource.snapshot_id('some_id')
      resource.snapshot_id.should == 'some_id'
    end

    it "has a max_snapshots attribute to clean up number of snapshots exceeding this value" do
      resource.max_snapshots(10)
      resource.max_snapshots.should == 10
    end

    it "has a max_snapshots attribute which takes only integer values" do
      expect { resource.max_snapshots('10') }.to raise_error
    end

    it "has a timeout attribute to set time out value for actions" do
      resource.timeout(10)
      resource.timeout.should == 10
    end

    it "has a timeout attribute which takes only integer values" do
      expect { resource.max_snapshots('10') }.to raise_error
    end

    it "has an options attribute to pass optional parameters like volume type" do
      resource.options({:key => 'value'})
      resource.options.should == {:key => 'value'}
    end

    it "has an options attribute which takes only hashes" do
      expect { resource.options('10') }.to raise_error
    end
  end
end
