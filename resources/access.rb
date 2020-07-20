# frozen_string_literal: true
#
# Cookbook:: postgresql
# Resource:: access
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

property :access_type,       String, default: 'local'
property :access_db,         String, default: 'all'
property :access_user,       String, default: 'postgres'
property :access_method,     String, default: 'ident'
property :cookbook,          String, default: 'postgresql'
property :source,            String, default: 'pg_hba.conf.erb'
property :access_addr,       String
property :comment,           String
property :apply_immediately, [true, false], default: false

action :grant do
  if new_resource.apply_immediately
    # Set up pg_hba.conf so that the rule can be immediately enforced
    # This change is temporary as the resource will then edit pg_hba.conf
    # as usual at a delayed time with all the rules collected at runtime
    pg_access =
      <<~EOH.gsub(/\n/, '')
        #{new_resource.access_type.ljust(8)}
        #{new_resource.access_db.ljust(16)}
        #{new_resource.access_user.ljust(16)}
        #{(new_resource.access_addr ? new_resource.access_addr : "").ljust(24)}
        #{new_resource.access_method}
      EOH
    append_if_no_line "immediately apply access rule in pg_hba.conf" do
      path "#{conf_dir}/pg_hba.conf"
      line pg_access
      ignore_missing false
      sensitive false
    end
  end

  config_resource = new_resource
  with_run_context :root do
    edit_resource(:template, "#{conf_dir}/pg_hba.conf") do |new_resource|
      source new_resource.source
      cookbook new_resource.cookbook
      owner 'postgres'
      group 'postgres'
      mode '0600'
      variables[:pg_hba] ||= {}
      variables[:pg_hba][new_resource.name] = {
        comment: new_resource.comment,
        type: new_resource.access_type,
        db: new_resource.access_db,
        user: new_resource.access_user,
        addr: new_resource.access_addr,
        method: new_resource.access_method,
      }
      action :nothing
      delayed_action :create
      notifies :trigger, config_resource, :immediately
    end
  end
end

action :trigger do
  new_resource.updated_by_last_action(true)
end

action_class do
  include PostgresqlCookbook::Helpers
end
