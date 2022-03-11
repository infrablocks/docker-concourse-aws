require 'spec_helper'

describe 'commands' do
  image = 'concourse-aws:latest'
  extra = {
      'Entrypoint' => '/bin/sh',
  }

  before(:all) do
    set :backend, :docker
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  after(:all, &:reset_docker_backend)

  it "includes the concourse command" do
    expect(command('/opt/concourse/bin/concourse --version').stdout)
      .to(match(/7.7.0/))
  end

  ['bash', 'curl', 'dumb-init'].each do |apk|
    it "includes #{apk}" do
      expect(package(apk)).to be_installed
    end
  end

  it "includes the AWS CLI" do
    expect(command('aws --version').stdout)
        .to(match(/aws-cli\/1/))
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end
end
