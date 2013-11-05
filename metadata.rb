name             'rightscale_volume'
maintainer       'RightScale, Inc.'
maintainer_email 'cookbooks@rightscale.com'
license          'Apache 2.0'
description      'Provides a resource to manage volumes on any cloud RightScale supports.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.0.0'

recipe "rightscale_volume::default", "Default recipe for installing required packages/gems."
