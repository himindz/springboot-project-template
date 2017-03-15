service_name = node['{{artifactId}}']['service']['name']

demo_web_app service_name do
  action :uninstall
end
