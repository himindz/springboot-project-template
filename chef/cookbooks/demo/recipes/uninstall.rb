service_name = node['demo']['service']['name']

demo_web_app service_name do
  action :uninstall
end
