name             'demo'
description      'Installs/Configures demo microservice'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.0.1'
depends 'java'
attribute 'artifact/version',
  :display_name => 'Artifact version',
  :type => 'string',
  :required => 'required'
