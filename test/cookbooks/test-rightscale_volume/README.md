# test-rightscale_volume cookbook

# Description

This is a wrapper cookbook to test the `rightscale_volume` cookbook.

# Requirements

See `rightscale_volume` [README][readme_link] for the requirements.

[readme_link]: https://github.com/rightscale-cookbooks/rightscale_volume/blob/master/README.md

# Recipes

## test

The `test` recipe tests every action supported by the `rightscale_volume` resource. It also
provides examples on how the `rightscale_volume` resource can be used in recipes.

To test the `rightscale_volume` cookbook, add this recipe to the run list.

# Libraries

## RightscaleVolumeTest::Helper

It is a collection of helper methods that can be used for validation when testing the
`rightscale_volume` cookbook. The helper methods use the `right_api_client` for making
instance facing API calls.

# Author

Author:: RightScale, Inc. (<cookbooks@rightscale.com>)
