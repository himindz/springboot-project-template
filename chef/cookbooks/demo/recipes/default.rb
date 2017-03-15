service_name = node['{{artifactId}}']['service']['name']
app_user = node['{{artifactId}}']['service']['user']
app_group = node['{{artifactId}}']['service']['group']
app_port = node['{{artifactId}}']['service']['port']
repo_artifact_path=node['{{artifactId}}']['repo']

artifact_name=node['{{artifactId}}']['artifact']['name']
artifact_version=node['{{artifactId}}']['artifact']['version']
artifact_path="#{artifact_name}-#{artifact_version}"
artifact_filename="#{artifact_path}.#{node['{{artifactId}}']['artifact']['extension']}"

base_path="#{node['{{artifactId}}']['app_path']}/#{service_name}"

install_link="#{base_path}/#{service_name}"
install_path="#{base_path}/#{artifact_path}"
log_path=base_path


if node.attribute?('{{artifactId}}') and node['{{artifactId}}'].attribute?('app')  and node['{{artifactId}}']['app'].attribute?('defines')
  java_opts = {}.merge(node['{{artifactId}}']['app']['java_opts'])
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
