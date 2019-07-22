#
# Cookbook:: postgresql
# Resource:: database
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

property :database, String, name_property: true
property :template, String, default: 'template1'
property :encoding, String, default: 'UTF-8'
property :locale,   String, default: 'en_US.UTF-8'
property :owner,    String

# Connection prefernces
property :user,               String, default: 'postgres'
property :ctrl_password,      String, sensitive: true
property :host,               String
property :port,               Integer, default: 5432
property :remote_connection,  [true, false], default: false

action :create do
  createdb = 'createdb'
  createdb << " -E #{new_resource.encoding}" if new_resource.encoding
  createdb << " -l #{new_resource.locale}" if new_resource.locale
  createdb << " -T #{new_resource.template}" unless new_resource.template.empty?
  createdb << " -O #{new_resource.owner}" if new_resource.owner
  createdb << " -U #{new_resource.user}"
  createdb << " -h #{new_resource.host}" if new_resource.host
  createdb << " -p #{new_resource.port}"
  createdb << " #{new_resource.database}"

  bash "create database #{new_resource.database}" do
    code createdb
    user new_resource.user unless new_resource.remote_connection
    environment cmd_environment
    sensitive true
    not_if { ! new_resource.remote_connection && follower? }
    not_if { database_exists?(new_resource) }
  end
end

action :drop do
  converge_by "drop PostgreSQL database #{new_resource.database}" do
    dropdb = 'dropdb'
    dropdb << " -U #{new_resource.user}" if new_resource.user
    dropdb << " --host #{new_resource.host}" if new_resource.host
    dropdb << " --port #{new_resource.port}" if new_resource.port
    dropdb << " #{new_resource.database}"

    bash "drop Postgresql database #{new_resource.database})" do
      code dropdb
      user 'postgres' unless new_resource.remote_connection
      environment cmd_environment
      sensitive true
      not_if { ! new_resource.remote_connection && follower? }
      only_if { database_exists?(new_resource) }
    end
  end
end

action_class do
  include PostgresqlCookbook::Helpers

  def cmd_environment
    if new_resource.ctrl_password
      psql_environment.merge('PGPASSWORD' => new_resource.ctrl_password)
    else
      psql_environment
    end
  end
end
