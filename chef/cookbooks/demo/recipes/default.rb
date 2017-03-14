service_name = node['demo']['service']['name']
app_user = node['demo']['service']['user']
app_group = node['demo']['service']['group']
app_port = node['demo']['service']['port']
repo_artifact_path=node['demo']['repo']

artifact_name=node['demo']['artifact']['name']
artifact_version=node['demo']['artifact']['version']
artifact_path="#{artifact_name}-#{artifact_version}"
artifact_filename="#{artifact_path}.#{node['demo']['artifact']['extension']}"

base_path="#{node['demo']['app_path']}/#{service_name}"

install_link="#{base_path}/#{service_name}"
install_path="#{base_path}/#{artifact_path}"
log_path=base_path


if node.attribute?('demo') and node['demo'].attribute?('app')  and node['demo-http-microservice']['app'].attribute?('defines')
  java_opts = {}.merge(node['demo']['app']['java_opts'])
else
  java_opts = {}
end


web_app_jar = '#{repo_artifact_path}/#{artifact_name}-#{artifact_version}.jar'

spring_boot_web_app service_name do
  jar_remote_path web_app_jar
  user app_user
  group app_group
  port app_port
  java_opts java_opts.to_s
  wait_for_http true
  wait_for_http_retries 60
  wait_for_http_retry_delay 2
end
