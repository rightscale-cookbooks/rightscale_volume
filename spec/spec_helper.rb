lib = File.expand_path('../../libraries', __FILE__)
$:.unshift(lib) unless $:.include?(lib)

require 'chef'
require 'provider_rightscale_volume'
require 'resource_rightscale_volume'
require 'right_api_client'
