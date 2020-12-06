require 'spec_helper'

describe 'concourse-web-aws entrypoint' do
  metadata_service_url = 'http://metadata:1338'
  s3_endpoint_url = 'http://s3:4566'
  s3_bucket_region = 'us-east-1'
  s3_bucket_path = 's3://bucket'
  s3_env_file_object_path = 's3://bucket/env-file.env'

  environment = {
      'AWS_METADATA_SERVICE_URL' => metadata_service_url,
      'AWS_ACCESS_KEY_ID' => "...",
      'AWS_SECRET_ACCESS_KEY' => "...",
      'AWS_S3_ENDPOINT_URL' => s3_endpoint_url,
      'AWS_S3_BUCKET_REGION' => s3_bucket_region,
      'AWS_S3_ENV_FILE_OBJECT_PATH' => s3_env_file_object_path
  }
  image = 'concourse-web-aws:latest'
  extra = {
      'Entrypoint' => '/bin/sh',
      'HostConfig' => {
          'NetworkMode' => 'docker_concourse_aws_test_default'
      }
  }

  default_env = {
      'CONCOURSE_POSTGRES_HOST' => 'db',
      'CONCOURSE_POSTGRES_USER' => 'concourse',
      'CONCOURSE_POSTGRES_PASSWORD' => 'concourse',
      'CONCOURSE_ADD_LOCAL_USER' => 'user:pass',
      'CONCOURSE_MAIN_TEAM_LOCAL_USER' => 'user'
  }

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

    before(:all) do
      create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: default_env.merge(
              'CONCOURSE_TSA_HOST_KEY' => '/tsa-host-key'
          ))

      execute_command(
          "echo \"#{tsa_host_key}\" > /tsa-host-key")

      execute_docker_entrypoint(
          started_indicator: "atc.listening")
    end

    after(:all, &:reset_docker_backend)

    it 'runs concourse web' do
      expect(process('concourse')).to(be_running)
      expect(process('concourse').args).to(match(/web/))
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

  describe 'with authentication configuration' do
    context 'when passed a filesystem path for the session signing key' do
      before(:all) do
        session_signing_key =
            File.read('spec/fixtures/session-signing-key.private')
        tsa_host_key =
            File.read('spec/fixtures/tsa-host-key.private')

        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: default_env.merge(
                'CONCOURSE_TSA_HOST_KEY_FILE_PATH' => '/tsa-host-key',
                'CONCOURSE_SESSION_SIGNING_KEY_FILE_PATH' => '/session-signing-key'
            ))

        execute_command(
            "echo \"#{tsa_host_key}\" > /tsa-host-key")
        execute_command(
            "echo \"#{session_signing_key}\" > /session-signing-key")

        execute_docker_entrypoint(
            started_indicator: "atc.listening")
      end

      after(:all, &:reset_docker_backend)

      it 'uses the provided file path as the session signing key' do
        expect(process('concourse').args)
            .to(match(
                /--session-signing-key=\/session-signing-key/))
      end
    end

    context 'when passed an object path for the session signing key' do
      def session_signing_key
        File.read('spec/fixtures/session-signing-key.private')
      end

      before(:all) do
        session_signing_key_object_path = "#{s3_bucket_path}/session-signing-key"
        tsa_host_key =
            File.read('spec/fixtures/tsa-host-key.private')

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: session_signing_key_object_path,
            content: session_signing_key)

        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: default_env.merge(
                'CONCOURSE_TSA_HOST_KEY_FILE_PATH' => '/tsa-host-key',
                'CONCOURSE_SESSION_SIGNING_KEY_FILE_OBJECT_PATH' =>
                    session_signing_key_object_path
            ))

        execute_command(
            "echo \"#{tsa_host_key}\" > /tsa-host-key")

        execute_docker_entrypoint(
            started_indicator: "atc.listening")
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified session signing key' do
        config_file_listing = command('ls /opt/concourse/conf').stdout

        expect(config_file_listing)
            .to(eq("session-signing-key\n"))

        session_signing_key_path = '/opt/concourse/conf/session-signing-key'
        session_signing_key_contents =
            command("cat #{session_signing_key_path}").stdout

        expect(session_signing_key_contents).to(eq(session_signing_key))
      end

      it 'uses the fetched session signing key' do
        key_path = '/opt/concourse/conf/session-signing-key'
        expect(process('concourse').args)
            .to(match(
                /--session-signing-key=#{Regexp.escape(key_path)}/))
      end
    end
  end

  describe 'with TSA configuration' do
    context 'when passed filesystem paths for the host and authorised keys' do
      before(:all) do
        tsa_host_key =
            File.read('spec/fixtures/tsa-host-key.private')
        tsa_authorized_keys =
            File.read('spec/fixtures/tsa-authorized-keys')

        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: default_env.merge(
                'CONCOURSE_TSA_HOST_KEY_FILE_PATH' =>
                    '/tsa-host-key',
                'CONCOURSE_TSA_AUTHORIZED_KEYS_FILE_PATH' =>
                    '/tsa-authorized-keys'
            ))

        execute_command(
            "echo \"#{tsa_host_key}\" > /tsa-host-key")
        execute_command(
            "echo \"#{tsa_authorized_keys}\" > /tsa-authorized-keys")

        execute_docker_entrypoint(
            started_indicator: "atc.listening")
      end

      after(:all, &:reset_docker_backend)

      it 'uses the provided file path as the TSA host key' do
        expect(process('concourse').args)
            .to(match(
                /--tsa-host-key=\/tsa-host-key/))
      end

      it 'uses the provided file path as the TSA authorized keys' do
        expect(process('concourse').args)
            .to(match(
                /--tsa-authorized-keys=\/tsa-authorized-keys/))
      end
    end

    context 'when passed an object path for the session signing key' do
      def tsa_host_key
        File.read('spec/fixtures/tsa-host-key.private')
      end

      def tsa_authorized_keys
        File.read('spec/fixtures/tsa-authorized-keys')
      end

      before(:all) do
        tsa_host_key_object_path =
            "#{s3_bucket_path}/tsa-host-key"
        tsa_authorized_keys_object_path =
            "#{s3_bucket_path}/tsa-authorized-keys"

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: tsa_host_key_object_path,
            content: tsa_host_key)

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: tsa_authorized_keys_object_path,
            content: tsa_authorized_keys)

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
            ))

        execute_docker_entrypoint(
            started_indicator: "atc.listening")
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified TSA host key and TSA authorized keys' do
        config_file_listing = command('ls /opt/concourse/conf').stdout

        expect(config_file_listing)
            .to(eq([
                "tsa-authorized-keys",
                "tsa-host-key",
            ].join("\n") + "\n"))

        tsa_host_key_path = '/opt/concourse/conf/tsa-host-key'
        tsa_host_key_contents =
            command("cat #{tsa_host_key_path}").stdout

        tsa_authorized_keys_path = '/opt/concourse/conf/tsa-authorized-keys'
        tsa_authorized_keys_contents =
            command("cat #{tsa_authorized_keys_path}").stdout

        expect(tsa_host_key_contents).to(eq(tsa_host_key))
        expect(tsa_authorized_keys_contents).to(eq(tsa_authorized_keys))
      end

      it 'uses the fetched TSA host key' do
        key_path = '/opt/concourse/conf/tsa-host-key'
        expect(process('concourse').args)
            .to(match(
                /--tsa-host-key=#{Regexp.escape(key_path)}/))
      end

      it 'uses the fetched TSA authorized keys' do
        key_path = '/opt/concourse/conf/tsa-authorized-keys'
        expect(process('concourse').args)
            .to(match(
                /--tsa-authorized-keys=#{Regexp.escape(key_path)}/))
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
      raise RuntimeError,
          "\"#{command_string}\" failed with exit code: #{exit_status}"
    end
    command
  end

  def create_object(opts)
    execute_command('aws ' +
        "--endpoint-url #{opts[:endpoint_url]} " +
        's3 ' +
        'mb ' +
        "#{opts[:bucket_path]} " +
        "--region \"#{opts[:region]}\"")
    execute_command("echo -n #{Shellwords.escape(opts[:content])} | " +
        'aws ' +
        "--endpoint-url #{opts[:endpoint_url]} " +
        's3 ' +
        'cp ' +
        '- ' +
        "#{opts[:object_path]} " +
        "--region \"#{opts[:region]}\" " +
        '--sse AES256')
  end

  def execute_docker_entrypoint(opts)
    logfile_path = '/tmp/docker-entrypoint.log'
    args = (opts[:arguments] || []).join(' ')

    execute_command(
        "docker-entrypoint.sh #{args} > #{logfile_path} 2>&1 &")

    begin
      Octopoller.poll(timeout: 10) do
        docker_entrypoint_log = command("cat #{logfile_path}").stdout
        docker_entrypoint_log =~ /#{opts[:started_indicator]}/ ?
            docker_entrypoint_log :
            :re_poll
      end
    rescue Octopoller::TimeoutError => e
      puts command("cat #{logfile_path}").stdout
      raise e
    end
  end
end