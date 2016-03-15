#
# Author:: Ranjib Dey (ranjib@pagerduty.com)
# Author:: Luke Kosewski (<luke@pagerduty.com>)
# Contact:: ops+opensource@pagerduty.com
# Cookbook Name:: sumologic
# Recipe:: default
#
# Copyright 2015, PagerDuty, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if not node['sumologic']['disabled']
  include_recipe 'chef-sumologic::install' 
  include_recipe 'chef-sumologic::sumoconf'

  node.set['sumologic']['use_json_path_dir'] == true
  # use the recipe sumojsondir if your source configurations are in a directory
  include_recipe 'chef-sumologic::sumojsondir'


  service 'collector' do
    supports start: true, status: true, restart: true
    action :start
  end

end
