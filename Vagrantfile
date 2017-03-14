# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'rbconfig'
require 'bcrypt'

def os
  @os ||= (
  host_os = RbConfig::CONFIG['host_os']
  case host_os
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      :windows
    when /darwin|mac os/
      :macosx
    when /linux/
      :linux
    when /solaris|bsd/
      :unix
    else
      raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
  end
  )
end

home_folder = ENV['HOME']
if os().to_s == 'windows'
  username = ENV['USER']
  home_folder = "/home/"+username
end


settings = YAML.load_file 'vagrant.yml'
password_hash='#jbcrypt:'+Shellwords.escape(BCrypt::Password.create(settings['user']['default_password']))
puts password_hash
dev_uid = Process.uid
ssh_folder = home_folder+"/.ssh"
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant"
  config.vm.define "devimage" do |a|
    a.vm.provider "docker" do |d|
      d.build_dir = "./docker/local-dev-image"
      d.build_args = ["--tag=localdevimage",
                      "--no-cache",
                      "--build-arg=USER_NAME=#{settings['user']['name']}",
                      "--build-arg=FULL_NAME=#{settings['user']['full_name']}",
                      "--build-arg=USER_EMAIL=#{settings['user']['email']}",
                      "--build-arg=PASSWORD=#{settings['user']['default_password']}",
                      "--build-arg=PASSWORD_HASH=#{password_hash}"
      ]
      d.force_host_vm = true
      d.env = {"DEV_UID"=>dev_uid,"USERNAME"=>settings['user']['name'],"HOME_FOLDER"=>home_folder,"DEFAULT_PASSWORD"=>settings['user']['default_password'],"USER_NAME"=>settings['user']['name'],"FULL_NAME"=>settings['user']['full_name'],"USER_EMAIL"=>settings['user']['email']}
      d.volumes = ["/vagrant:"+home_folder+"/"+settings['microservice']['name']]
      d.ports = [settings['local_jenkins_port'].to_s+":8080",settings['dev_image_ssh_port'].to_s+":22"]
      d.vagrant_machine = settings['microservice']['name']
      d.vagrant_vagrantfile = "./DockerHostVagrantfile"
    end
  end
  config.vm.define "qaimage" do |a|
    a.vm.provider "docker" do |d|
      d.image = "qaimage"
      d.force_host_vm = true
      d.has_ssh = false
      d.cmd = ["/bin/bash"]
      d.volumes = ["/vagrant:/git"]
      d.vagrant_machine = settings['microservice']['name']
      d.vagrant_vagrantfile = "./DockerHostVagrantfile"
      d.remains_running = false
    end
  end

end
