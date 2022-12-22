# frozen_string_literal: true

require 'spec_helper'

describe 'concourse-web-aws entrypoint' do
  def metadata_service_url
    'http://metadata:1338'
  end

  def s3_endpoint_url
    'http://s3:4566'
  end

  def s3_bucket_region
    'us-east-1'
  end

  def s3_bucket_path
    's3://bucket'
  end

  def s3_env_file_object_path
    's3://bucket/env-file.env'
  end

  def environment
    {
      'AWS_METADATA_SERVICE_URL' => metadata_service_url,
      'AWS_ACCESS_KEY_ID' => '...',
      'AWS_SECRET_ACCESS_KEY' => '...',
      'AWS_S3_ENDPOINT_URL' => s3_endpoint_url,
      'AWS_S3_BUCKET_REGION' => s3_bucket_region,
      'AWS_S3_ENV_FILE_OBJECT_PATH' => s3_env_file_object_path
    }
  end

  def image
    'concourse-web-aws:latest'
  end

  def extra
    {
      'Entrypoint' => '/bin/sh',
      'HostConfig' => {
        'NetworkMode' => 'docker_concourse_aws_test_default'
      }
    }
  end

  def default_env
    {
      'CONCOURSE_POSTGRES_HOST' => 'db',
      'CONCOURSE_POSTGRES_USER' => 'concourse',
      'CONCOURSE_POSTGRES_PASSWORD' => 'concourse',
      'CONCOURSE_ADD_LOCAL_USER' => 'user:pass',
      'CONCOURSE_MAIN_TEAM_LOCAL_USER' => 'user'
    }
  end

  before(:all) do
    set :backend, :docker
    set :env, environment
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  describe 'by default' do
    def tsa_host_key
      File.read('spec/fixtures/tsa-host-key.private')
    end

    def tsa_host_key_file_path
      '/tsa-host-key'
    end

    before(:all) do
      create_env_file(
        endpoint_url: s3_endpoint_url,
        region: s3_bucket_region,
        bucket_path: s3_bucket_path,
        object_path: s3_env_file_object_path,
        env: default_env.merge(
          'CONCOURSE_TSA_HOST_KEY_FILE_PATH' => tsa_host_key_file_path
        )
      )

      write_file(tsa_host_key, tsa_host_key_file_path)

      execute_docker_entrypoint(
        started_indicator: 'atc.listening'
      )
    end

    after(:all, &:reset_docker_backend)

    it 'runs the concourse binary' do
      expect(process('concourse')).to(be_running)
    end

    it 'runs the web subcommand of the concourse binary' do
      expect(process('concourse').args).to(match(/web/))
    end

    it 'uses the self IP as the peer address' do
      expect(process('concourse').args)
        .to(match(/--peer-address=172\.16\.34\.43/))
    end

    it 'runs with the root user' do
      expect(process('concourse').user)
        .to(eq('root'))
    end

    it 'runs with the root group' do
      expect(process('concourse').group)
        .to(eq('root'))
    end
  end

  describe 'with general configuration' do
    def tsa_host_key
      File.read('spec/fixtures/tsa-host-key.private')
    end

    def tsa_host_key_file_path
      '/tsa-host-key'
    end

    before(:all) do
      create_env_file(
        endpoint_url: s3_endpoint_url,
        region: s3_bucket_region,
        bucket_path: s3_bucket_path,
        object_path: s3_env_file_object_path,
        env: default_env.merge(
          'CONCOURSE_TSA_HOST_KEY_FILE_PATH' => tsa_host_key_file_path,
          'CONCOURSE_PEER_ADDRESS' => '127.0.0.1'
        )
      )

      write_file(tsa_host_key, tsa_host_key_file_path)

      execute_docker_entrypoint(
        started_indicator: 'atc.listening'
      )
    end

    after(:all, &:reset_docker_backend)

    it 'uses the provided peer address' do
      expect(process('concourse').args)
        .to(match(/--peer-address=127\.0\.0\.1/))
    end
  end

  describe 'with authentication configuration' do
    context 'when passed a filesystem path for the session signing key' do
      def tsa_host_key
        File.read('spec/fixtures/tsa-host-key.private')
      end

      def session_signing_key
        File.read('spec/fixtures/session-signing-key.private')
      end

      def tsa_host_key_file_path
        '/tsa-host-key'
      end

      def session_signing_key_file_path
        '/session-signing-key'
      end

      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: default_env.merge(
            'CONCOURSE_TSA_HOST_KEY_FILE_PATH' => tsa_host_key_file_path,
            'CONCOURSE_SESSION_SIGNING_KEY_FILE_PATH' =>
              session_signing_key_file_path
          )
        )

        write_file(tsa_host_key, tsa_host_key_file_path)
        write_file(session_signing_key, session_signing_key_file_path)

        execute_docker_entrypoint(
          started_indicator: 'atc.listening'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'uses the provided file path as the session signing key' do
        expect(process('concourse').args)
          .to(match(
                %r{--session-signing-key=/session-signing-key}
              ))
      end
    end

    context 'when passed an object path for the session signing key' do
      def session_signing_key
        File.read('spec/fixtures/session-signing-key.private')
      end

      def tsa_host_key
        File.read('spec/fixtures/tsa-host-key.private')
      end

      def tsa_host_key_file_path
        '/tsa-host-key'
      end

      def session_signing_key_object_path
        "#{s3_bucket_path}/session-signing-key"
      end

      before(:all) do
        create_object(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: session_signing_key_object_path,
          content: session_signing_key
        )

        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: default_env.merge(
            'CONCOURSE_TSA_HOST_KEY_FILE_PATH' => tsa_host_key_file_path,
            'CONCOURSE_SESSION_SIGNING_KEY_FILE_OBJECT_PATH' =>
                session_signing_key_object_path
          )
        )

        write_file(tsa_host_key, tsa_host_key_file_path)

        execute_docker_entrypoint(
          started_indicator: 'atc.listening'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified session signing key' do
        config_file_listing = command('ls /opt/concourse/conf').stdout

        expect(config_file_listing)
          .to(eq("session-signing-key\n"))
      end

      it 'uses the correct session signing key content' do
        session_signing_key_path = '/opt/concourse/conf/session-signing-key'
        session_signing_key_contents =
          command("cat #{session_signing_key_path}").stdout

        expect(session_signing_key_contents).to(eq(session_signing_key))
      end

      it 'uses the fetched session signing key' do
        key_path = '/opt/concourse/conf/session-signing-key'
        expect(process('concourse').args)
          .to(match(
                /--session-signing-key=#{Regexp.escape(key_path)}/
              ))
      end
    end
  end

  describe 'with TSA configuration' do
    context 'when passed filesystem paths for the host and authorised keys' do
      def tsa_host_key
        File.read('spec/fixtures/tsa-host-key.private')
      end

      def tsa_authorized_keys
        File.read('spec/fixtures/tsa-authorized-keys')
      end

      def tsa_host_key_file_path
        '/tsa-host-key'
      end

      def tsa_authorized_keys_file_path
        '/tsa-authorized-keys'
      end

      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: default_env.merge(
            'CONCOURSE_TSA_HOST_KEY_FILE_PATH' =>
              tsa_host_key_file_path,
            'CONCOURSE_TSA_AUTHORIZED_KEYS_FILE_PATH' =>
              tsa_authorized_keys_file_path
          )
        )

        write_file(tsa_host_key, tsa_host_key_file_path)
        write_file(tsa_authorized_keys, tsa_authorized_keys_file_path)

        execute_docker_entrypoint(
          started_indicator: 'atc.listening'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'uses the provided file path as the TSA host key' do
        expect(process('concourse').args)
          .to(match(
                %r{--tsa-host-key=/tsa-host-key}
              ))
      end

      it 'uses the provided file path as the TSA authorized keys' do
        expect(process('concourse').args)
          .to(match(
                %r{--tsa-authorized-keys=/tsa-authorized-keys}
              ))
      end
    end

    context 'when passed an object path for the session signing key' do
      def tsa_host_key
        File.read('spec/fixtures/tsa-host-key.private')
      end

      def tsa_authorized_keys
        File.read('spec/fixtures/tsa-authorized-keys')
      end

      def tsa_host_key_object_path
        "#{s3_bucket_path}/tsa-host-key"
      end

      def tsa_authorized_keys_object_path
        "#{s3_bucket_path}/tsa-authorized-keys"
      end

      def create_object_in_bucket(content, path)
        create_object(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: path,
          content:
        )
      end

      before(:all) do
        create_object_in_bucket(
          tsa_host_key, tsa_host_key_object_path
        )
        create_object_in_bucket(
          tsa_authorized_keys, tsa_authorized_keys_object_path
        )

        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: default_env.merge(
            'CONCOURSE_TSA_HOST_KEY_FILE_OBJECT_PATH' =>
                tsa_host_key_object_path,
            'CONCOURSE_TSA_AUTHORIZED_KEYS_FILE_OBJECT_PATH' =>
                tsa_authorized_keys_object_path
          )
        )

        execute_docker_entrypoint(
          started_indicator: 'atc.listening'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'fetches TSA host key and TSA authorized keys' do
        config_file_listing = command('ls /opt/concourse/conf').stdout

        expect(config_file_listing)
          .to(eq("tsa-authorized-keys\ntsa-host-key\n"))
      end

      it 'fetches the correct TSA host key contents' do
        tsa_host_key_path = '/opt/concourse/conf/tsa-host-key'
        tsa_host_key_contents =
          command("cat #{tsa_host_key_path}").stdout

        expect(tsa_host_key_contents).to(eq(tsa_host_key))
      end

      it 'fetches the correct TSA authorized keys contents' do
        tsa_authorized_keys_path = '/opt/concourse/conf/tsa-authorized-keys'
        tsa_authorized_keys_contents =
          command("cat #{tsa_authorized_keys_path}").stdout

        expect(tsa_authorized_keys_contents).to(eq(tsa_authorized_keys))
      end

      it 'uses the fetched TSA host key' do
        key_path = '/opt/concourse/conf/tsa-host-key'
        expect(process('concourse').args)
          .to(match(
                /--tsa-host-key=#{Regexp.escape(key_path)}/
              ))
      end

      it 'uses the fetched TSA authorized keys' do
        key_path = '/opt/concourse/conf/tsa-authorized-keys'
        expect(process('concourse').args)
          .to(match(
                /--tsa-authorized-keys=#{Regexp.escape(key_path)}/
              ))
      end
    end
  end

  def reset_docker_backend
    Specinfra::Backend::Docker.instance.send :cleanup_container
    Specinfra::Backend::Docker.clear
  end

  def create_env_file(opts)
    create_object(opts
        .merge(content: (opts[:env] || {})
            .to_a
            .collect { |item| " #{item[0]}=\"#{item[1]}\"" }
            .join("\n")))
  end

  def execute_command(command_string)
    command = command(command_string)
    exit_status = command.exit_status
    unless exit_status == 0
      raise "\"#{command_string}\" failed with exit code: #{exit_status}"
    end

    command
  end

  def write_file(contents, path)
    execute_command(
      "echo \"#{contents}\" > #{path}"
    )
  end

  def make_bucket(opts)
    execute_command('aws ' \
                    "--endpoint-url #{opts[:endpoint_url]} " \
                    's3 ' \
                    'mb ' \
                    "#{opts[:bucket_path]} " \
                    "--region \"#{opts[:region]}\"")
  end

  def copy_object(opts)
    execute_command("echo -n #{Shellwords.escape(opts[:content])} | " \
                    'aws ' \
                    "--endpoint-url #{opts[:endpoint_url]} " \
                    's3 ' \
                    'cp ' \
                    '- ' \
                    "#{opts[:object_path]} " \
                    "--region \"#{opts[:region]}\" " \
                    '--sse AES256')
  end

  def create_object(opts)
    make_bucket(opts)
    copy_object(opts)
  end

  def wait_for_contents(file, content)
    Octopoller.poll(timeout: 30) do
      docker_entrypoint_log = command("cat #{file}").stdout
      docker_entrypoint_log =~ /#{content}/ ? docker_entrypoint_log : :re_poll
    end
  rescue Octopoller::TimeoutError => e
    puts command("cat #{file}").stdout
    raise e
  rescue Excon::Error::NotFound => _e
    puts 'Container stopped before expected output present.'
  end

  def execute_docker_entrypoint(opts)
    args = (opts[:arguments] || []).join(' ')
    logfile_path = '/tmp/docker-entrypoint.log'
    start_command = "docker-entrypoint.sh #{args} > #{logfile_path} 2>&1 &"
    started_indicator = opts[:started_indicator]

    execute_command(start_command)
    wait_for_contents(logfile_path, started_indicator)
  end
end
