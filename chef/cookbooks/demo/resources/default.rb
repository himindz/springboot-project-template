actions :uninstall, :install
default_action :install

attribute :name, kind_of: String
attribute :user, kind_of: String, default: '{{artifactId}}'
attribute :group, kind_of: String, default: '{{artifactId}}'
attribute :port, kind_of: Integer, default: 8080
attribute :app_remote_path, kind_of: String
attribute :app_install_path, kind_of: String, default: '/apps'
attribute :app_extension, kind_of: String, default: '.jar'

attribute :java_opts, kind_of: String, default: ''
attribute :boot_opts, kind_of: String, default: ''

attribute :init_system, kind_of: String, default: 'systemd'

attribute :wait_for_http, kind_of: [TrueClass, FalseClass], default: true
attribute :wait_for_http_retries, kind_of: Integer, default: 24
attribute :wait_for_http_retry_delay, kind_of: Integer, default: 5