name             'rightscale_volume'
maintainer       'RightScale, Inc.'
maintainer_email 'cookbooks@rightscale.com'
license          'Apache 2.0'
description      'Provides a resource to manage volumes on any cloud RightScale supports.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '2.0.0'
issues_url       'https://github.com/rightscale-cookbooks/rightscale_volume/issues' if respond_to?(:issues_url)
source_url       'https://github.com/rightscale-cookbooks/rightscale_volume' if respond_to?(:source_url)
chef_version     '>= 12.4' if respond_to?(:chef_version)

depends 'build-essential'
recipe 'rightscale_volume::default', 'Default recipe for installing required packages/gems.'
