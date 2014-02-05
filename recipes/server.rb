#
# Cookbook Name:: razor-server
# Recipe:: server

# Razor likes to run on top of their Torquebox design
include_recipe "razor-server::torquebox"

execute "wget razor-server" do
  command "wget #{node[:razor][:url]} -O /tmp/razor-server.zip"
  creates "/tmp/razor-server.zip"
end

ark "razor-server" do
#  url   node[:razor][:url]
  url      "file:///tmp/razor-server.zip"
  path  node[:razor][:base]
  owner node[:razor][:user]
  group node[:razor][:group]
  strip_leading_dir true
  mode 00755
  action :put
end

template "#{node[:razor][:dest]}/bin/razor-binary-wrapper" do
  source "razor-binary-wrapper.erb"
  owner  "root"
  group  "root"
  mode   00755
end

link "/usr/local/bin/razor-admin" do
  to "#{node[:razor][:dest]}/bin/razor-binary-wrapper"
end

file "#{node[:razor][:dest]}/bin/razor-admin" do
  mode  00755
end

directory node[:razor][:repo] do
  owner node[:razor][:user]
  group node[:razor][:group]
  recursive true
  mode  00755
  action :create
end

directory "#{node[:razor][:dest]}/log" do
  owner node[:razor][:user]
  group node[:razor][:group]
  mode  00755
end

file "#{node[:razor][:dest]}/log/production.log" do
  owner node[:razor][:user]
  group node[:razor][:group]
  mode  00660
end

execute "Install Bundler" do
  command "gem install bundler"
  path    ["#{node[:razor][:torquebox][:dest]}/jruby/bin"]
  cwd     node[:razor][:dest]
  environment(
    "PATH" => "#{node[:razor][:torquebox][:dest]}/jruby/bin:/bin:/usr/bin:/usr/local/bin",
  )
end

execute "Install Gems" do
  command "bundle install"
  path    ["#{node[:razor][:torquebox][:dest]}/jruby/bin"]
  cwd     node[:razor][:dest]
  environment(
    "PATH" => "#{node[:razor][:torquebox][:dest]}/jruby/bin:/bin:/usr/bin:/usr/local/bin",
  )
end

execute "Deploy razor into torquebox" do
  command "#{node[:razor][:torquebox][:dest]}/jruby/bin/torquebox deploy --env production"
  creates "#{node[:razor][:torquebox][:dest]}/jboss/standalone/deployments/razor-knob.yml"
  cwd     node[:razor][:dest]
  environment(
    "PATH" => "#{node[:razor][:torquebox][:dest]}/jruby/bin:/bin:/usr/bin:/usr/local/bin",
    "TORQUEBOX_HOME" => node[:razor][:torquebox][:dest],
    "JBOSS_HOME" => "#{node[:razor][:torquebox][:dest]}/jboss",
    "JRUBY_HOME" => "#{node[:razor][:torquebox][:dest]}/jruby"
  )
end

template "#{node[:razor][:dest]}/config.yaml" do
  source "config.yaml.erb"
  owner node[:razor][:user]
  group node[:razor][:group]
  mode  00660
end

execute "Create/Migrate database" do
  command "razor-admin -e production migrate-database"
  path    ["/usr/local/bin"]
  cwd     node[:razor][:dest]
  action  :nothing
  subscribes :run, "template[#{node[:razor][:dest]}/config.yaml]", :immediately
end

execute "wget razor-microkernel" do
  command "wget #{node[:razor][:microkernel][:url]} -O /tmp/razor-microkernel.tar.gz"
  creates "/tmp/razor-microkernel.tar.gz"
end

ark "razor-microkernel" do
#  url   node[:razor][:microkernel][:url]
  url   "file:///tmp/razor-microkernel.tar.gz"
  path  "#{node[:razor][:repo]}/"
  owner node[:razor][:user]
  group node[:razor][:group]
  action :put
end


if node[:razor][:tftp]
  include_recipe "razor-server::tftp"
end

if node[:razor][:dhcp]
  include_recipe "razor-server::dhcp"
end
