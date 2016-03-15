#
# Author:: Duc Ha (<duc@sumologic.com>)
# Cookbook Name:: sumologic-collector
# Recipe:: Configure a directory with individual json files for configuring sources. The directory path is specified by the attribute `default['sumologic']['sumo_json_path']`
#
#
# Copyright 2015, Sumo Logic
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
#

# This is a setup configuration file, could be used to manage colector source configuration through local json files.
#
# Sumo Logic Help Links
# https://service.sumologic.com/ui/help/Default.htm#Unattended_Installation_from_a_Linux_Script_using_the_Collector_Management_API.htm
# https://service.sumologic.com/ui/help/Default.htm#Using_sumo.conf.htm
# https://service.sumologic.com/ui/help/Default.htm#JSON_Source_Configuration.htm
# https://service.sumologic.com/help/Default.htm#Using_Local_Configuration_File_Management.htm

# Create the json file's directory (generally for Windows support)
directory node['sumologic']['sumo_json_path'] do
  unless platform?('windows')
    owner 'root'
    group 'root'
    mode 0755
  end
  action :create
end

# add local json files here
if !platform?('windows')

  sumo_source 'system_log' do
    category 'OS/Linux/System'  # optional, defaults to 'log' or the category attr.
    default_timezone 'UTC'  # optional, defaults to UTC or timezone attr.
    force_timezone false # optional, defaults to false or the force attr.
    multiline_processing_enabled false
    case node["platform_family"]
    when 'rhel'
      path '/var/log/messages'
    when 'debian'
      path '/var/log/syslog'
    end
  end

  sumo_source 'security_log' do
    category 'OS/Linux/Security'  # optional, defaults to 'log' or the category attr.
    default_timezone 'UTC'  # optional, defaults to UTC or timezone attr.
    force_timezone false # optional, defaults to false or the force attr.
    multiline_processing_enabled false
    case node["platform_family"]
    when 'rhel'
      path '/var/log/secure'
    when 'debian'
      path '/var/log/auth.log'
    end
  end

# This is an example of another local file source, note the use of variables in this template
# template "#{node['sumologic']['sumo_json_path']}/localfile-generic.json" do
#  cookbook node['sumologic']['json_config_cookbook']
#  source "localfile-dir.json.erb"
#  variables ({:source_name=>"Generic",:source_category=>"Chef",:pathExpression=>"/var/log/chef*.log"})
# end

# Below are examples of some other source types: remote file and syslog
# template "#{node['sumologic']['sumo_json_path']}/rfile.json" do
#  cookbook node['sumologic']['json_config_cookbook']
#  source "rfile-dir.json.erb"
# end

# template "#{node['sumologic']['sumo_json_path']}/syslog.json" do
#  cookbook node['sumologic']['json_config_cookbook']
#  source "syslog-dir.json.erb"
# end
elsif platform?('windows')
  template "#{node['sumologic']['sumo_json_path']}/sumo-windows.json" do
    #cookbook node['sumologic']['json_config_cookbook']
    source "sumo-windows-dir.json.erb"
  end
end
