name             'rightscale_volume'
maintainer       'RightScale, Inc.'
maintainer_email 'cookbooks@rightscale.com'
license          'Apache 2.0'
description      'Provides a rightscale_volume resource that can create, attach, and manage a single' +
                  ' block level storage "volume" on numerous public and private IaaS clouds.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          IO.read(File.join(File.dirname(__FILE__), 'VERSION')) rescue '0.1.0'

recipe "rightscale_volume::default", "Default recipe for installing required packages/gems."
