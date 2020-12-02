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
    expect(command('/usr/local/concourse/bin/concourse --version').stdout)
        .to(match(/6.7.2/))
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end
end
