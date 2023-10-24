# frozen_string_literal: true

require 'git'
require 'os'
require 'pathname'
require 'rake_circle_ci'
require 'rake_docker'
require 'rake_git'
require 'rake_git_crypt'
require 'rake_github'
require 'rake_gpg'
require 'rake_ssh'
require 'rake_terraform'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'securerandom'
require 'semantic'
require 'yaml'

require_relative 'lib/version'

Docker.options = {
  read_timeout: 300
}

def repo
  Git.open(Pathname.new('.'))
end

def latest_tag
  repo.tags.map do |tag|
    Semantic::Version.new(tag.name)
  end.max
end

def tmpdir
  base = (ENV['TMPDIR'] || '/tmp')
  OS.osx? ? "/private#{base}" : base
end

task default: %i[
  test:code:fix
  test:integration
]

RakeGitCrypt.define_standard_tasks(
  namespace: :git_crypt,

  provision_secrets_task_name: :'secrets:provision',
  destroy_secrets_task_name: :'secrets:destroy',

  install_commit_task_name: :'git:commit',
  uninstall_commit_task_name: :'git:commit',

  gpg_user_key_paths: %w[
    config/gpg
    config/secrets/ci/gpg.public
  ]
)

namespace :git do
  RakeGit.define_commit_task(
    argument_names: [:message]
  ) do |t, args|
    t.message = args.message
  end
end

namespace :encryption do
  namespace :directory do
    desc 'Ensure CI secrets directory exists.'
    task :ensure do
      FileUtils.mkdir_p('config/secrets/ci')
    end
  end

  namespace :passphrase do
    desc 'Generate encryption passphrase for CI GPG key'
    task generate: ['directory:ensure'] do
      File.write(
        'config/secrets/ci/encryption.passphrase',
        SecureRandom.base64(36)
      )
    end
  end
end

namespace :keys do
  namespace :deploy do
    RakeSSH.define_key_tasks(
      path: 'config/secrets/ci/',
      comment: 'maintainers@infrablocks.io'
    )
  end

  namespace :gpg do
    RakeGPG.define_generate_key_task(
      output_directory: 'config/secrets/ci',
      name_prefix: 'gpg',
      owner_name: 'InfraBlocks Maintainers',
      owner_email: 'maintainers@infrablocks.io',
      owner_comment: 'docker-concourse-aws CI Key'
    )
  end
end

namespace :secrets do
  namespace :directory do
    desc 'Ensure secrets directory exists and is set up correctly'
    task :ensure do
      FileUtils.mkdir_p('config/secrets')
      unless File.exist?('config/secrets/.unlocked')
        File.write('config/secrets/.unlocked', 'true')
      end
    end
  end

  desc 'Generate all generatable secrets.'
  task generate: %w[
    encryption:passphrase:generate
    keys:deploy:generate
    keys:gpg:generate
  ]

  desc 'Provision all secrets.'
  task provision: [:generate]

  desc 'Delete all secrets.'
  task :destroy do
    rm_rf 'config/secrets'
  end

  desc 'Rotate all secrets.'
  task rotate: [:'git_crypt:reinstall']
end

namespace :library do
  desc 'Run all checks of the library'
  task check: [:rubocop]

  desc 'Attempt to automatically fix issues with the library'
  task fix: [:'rubocop:autocorrect_all']
end

RakeCircleCI.define_project_tasks(
  namespace: :circle_ci,
  project_slug: 'github/infrablocks/docker-concourse-aws'
) do |t|
  circle_ci_config =
    YAML.load_file('config/secrets/circle_ci/config.yaml')

  t.api_token = circle_ci_config['circle_ci_api_token']
  t.environment_variables = {
    ENCRYPTION_PASSPHRASE:
        File.read('config/secrets/ci/encryption.passphrase')
            .chomp
  }
  t.checkout_keys = []
  t.ssh_keys = [
    {
      hostname: 'github.com',
      private_key: File.read('config/secrets/ci/ssh.private')
    }
  ]
end

RakeGithub.define_repository_tasks(
  namespace: :github,
  repository: 'infrablocks/docker-concourse-aws'
) do |t, args|
  github_config =
    YAML.load_file('config/secrets/github/config.yaml')

  t.access_token = github_config['github_personal_access_token']
  t.deploy_keys = [
    {
      title: 'CircleCI',
      public_key: File.read('config/secrets/ci/ssh.public')
    }
  ]
  t.branch_name = args.branch_name
  t.commit_message = args.commit_message
end

namespace :pipeline do
  desc 'Prepare CircleCI Pipeline'
  task prepare: %i[
    circle_ci:env_vars:ensure
    circle_ci:checkout_keys:ensure
    circle_ci:ssh_keys:ensure
    github:deploy_keys:ensure
  ]
end

# rubocop:disable Metrics/BlockLength
namespace :images do
  namespace :base do
    RakeDocker.define_image_tasks(
      image_name: 'concourse-aws'
    ) do |t|
      t.work_directory = 'build/images'

      t.copy_spec = %w[
        src/concourse-aws/Dockerfile
        src/concourse-aws/docker-entrypoint.sh
        src/concourse-aws/start.sh
      ]

      t.repository_name = 'concourse-aws'
      t.repository_url = 'infrablocks/concourse-aws'

      t.credentials = YAML.load_file(
        'config/secrets/dockerhub/credentials.yaml'
      )

      t.platform = 'linux/amd64'

      t.tags = [latest_tag.to_s, 'latest']
    end
  end

  namespace :web do
    RakeDocker.define_image_tasks(
      image_name: 'concourse-web-aws',
      argument_names: [:base_image_version]
    ) do |t, args|
      args.with_defaults(base_image_version: latest_tag.to_s)

      t.work_directory = 'build/images'

      t.copy_spec = %w[
        src/concourse-web-aws/Dockerfile
        src/concourse-web-aws/start.sh
      ]

      t.repository_name = 'concourse-web-aws'
      t.repository_url = 'infrablocks/concourse-web-aws'

      t.credentials = YAML.load_file(
        'config/secrets/dockerhub/credentials.yaml'
      )

      t.build_args = {
        BASE_IMAGE_VERSION: args.base_image_version
      }

      t.platform = 'linux/amd64'

      t.tags = [latest_tag.to_s, 'latest']
    end
  end

  namespace :worker do
    RakeDocker.define_image_tasks(
      image_name: 'concourse-worker-aws',
      argument_names: [:base_image_version]
    ) do |t, args|
      args.with_defaults(base_image_version: latest_tag.to_s)

      t.work_directory = 'build/images'

      t.copy_spec = %w[
        src/concourse-worker-aws/Dockerfile
        src/concourse-worker-aws/start.sh
      ]

      t.repository_name = 'concourse-worker-aws'
      t.repository_url = 'infrablocks/concourse-worker-aws'

      t.credentials = YAML.load_file(
        'config/secrets/dockerhub/credentials.yaml'
      )

      t.build_args = {
        BASE_IMAGE_VERSION: args.base_image_version
      }

      t.platform = 'linux/amd64'

      t.tags = [latest_tag.to_s, 'latest']
    end
  end

  desc 'Build all images'
  task :build do
    %w[images:base images:web images:worker].each do |t|
      Rake::Task["#{t}:build"].invoke('latest')
      Rake::Task["#{t}:tag"].invoke('latest')
    end
  end
end
# rubocop:enable Metrics/BlockLength

# rubocop:disable Metrics/BlockLength
namespace :dependencies do
  namespace :test do
    desc 'Provision spec dependencies'
    task :provision do
      project_name = 'docker_concourse_aws_test'
      compose_file = 'spec/dependencies.yml'

      project_name_switch = "--project-name #{project_name}"
      compose_file_switch = "--file #{compose_file}"
      detach_switch = '--detach'
      remove_orphans_switch = '--remove-orphans'

      command_switches = "#{compose_file_switch} #{project_name_switch}"
      subcommand_switches = "#{detach_switch} #{remove_orphans_switch}"

      sh({
           'TMPDIR' => tmpdir
         }, "docker-compose #{command_switches} up #{subcommand_switches}")
    end

    desc 'Destroy spec dependencies'
    task :destroy do
      project_name = 'docker_concourse_aws_test'
      compose_file = 'spec/dependencies.yml'

      project_name_switch = "--project-name #{project_name}"
      compose_file_switch = "--file #{compose_file}"

      command_switches = "#{compose_file_switch} #{project_name_switch}"

      sh({
           'TMPDIR' => tmpdir
         }, "docker-compose #{command_switches} down")
    end
  end
end
# rubocop:enable Metrics/BlockLength

namespace :fixtures do
  RakeSSH.define_key_tasks(
    namespace: :session_signing_key,
    path: 'spec/fixtures/',
    name_prefix: 'session-signing-key',
    comment: 'maintainers@infrablocks.io'
  )

  RakeSSH.define_key_tasks(
    namespace: :tsa_host_key,
    path: 'spec/fixtures/',
    name_prefix: 'tsa-host-key',
    comment: 'maintainers@infrablocks.io'
  )

  RakeSSH.define_key_tasks(
    namespace: :tsa_worker_private_key,
    path: 'spec/fixtures/',
    name_prefix: 'worker-key',
    comment: 'maintainers@infrablocks.io'
  )
end

RuboCop::RakeTask.new

namespace :test do
  namespace :code do
    desc 'Run all checks on the test code'
    task check: [:rubocop]

    desc 'Attempt to automatically fix issues with the test code'
    task fix: [:'rubocop:autocorrect_all']
  end

  RSpec::Core::RakeTask.new(:unit)

  RSpec::Core::RakeTask.new(
    integration: %w[images:build dependencies:test:provision]
  ) do |t|
    t.rspec_opts = %w[--format documentation]
  end
end

namespace :version do
  desc 'Bump version for specified type (pre, major, minor, patch)'
  task :bump, [:type] do |_, args|
    next_tag = latest_tag.send("#{args.type}!")
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'main', tags: true)
  end

  desc 'Release gem'
  task :release do
    next_tag = latest_tag.release!
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'main', tags: true)
  end
end
