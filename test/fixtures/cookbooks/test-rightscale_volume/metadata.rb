name             'test-rightscale_volume'
maintainer       'RightScale, Inc.'
maintainer_email 'cookbooks@rightscale.com'
license          'Apache 2.0'
description      'A wrapper cookbook to test rightscale_volume cookbook'
version          IO.read(File.join(File.dirname(__FILE__), 'VERSION')) rescue '0.1.0'

depends 'rightscale_volume'
depends 'marker'
depends 'delayed_evaluator'

recipe 'test-rightscale_volume::test', 'Test recipe for testing rightscale_volume cookbook'
