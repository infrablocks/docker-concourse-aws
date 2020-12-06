require 'spec_helper'

describe 'concourse-worker-aws entrypoint' do
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
  image = 'concourse-worker-aws:latest'
  extra = {
      'Entrypoint' => '/bin/sh',
      'HostConfig' => {
          'Privileged' => true,
          'NetworkMode' => 'docker_concourse_aws_test_default'
      }
  }

  default_env = {
      'CONCOURSE_WORK_DIR' => '/var/opt/concourse'
  }

  before(:all) do
    set :backend, :docker
    set :env, environment
    set :docker_image, image
    set :docker_container_create_options, extra
  end

  describe 'by default' do
    def tsa_worker_private_key
      File.read('spec/fixtures/worker-key.private')
    end

    before(:all) do
      create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: default_env.merge(
              'CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH' =>
                  '/tsa-worker-private-key',
          ))

      execute_command(
          "echo \"#{tsa_worker_private_key}\" > /tsa-worker-private-key")

      execute_docker_entrypoint(
          started_indicator: "guardian.started")
    end

    after(:all, &:reset_docker_backend)

    it 'runs concourse worker' do
      expect(process('concourse')).to(be_running)
      expect(process('concourse').args).to(match(/worker/))
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

  describe 'with TSA configuration' do
    context 'when passed filesystem paths for the public key and worker ' +
        'private key' do
      before(:all) do
        tsa_public_key =
            File.read('spec/fixtures/tsa-host-key.public')
        tsa_worker_private_key =
            File.read('spec/fixtures/worker-key.private')

        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: default_env.merge(
                'CONCOURSE_TSA_PUBLIC_KEY_FILE_PATH' =>
                    '/tsa-public-key',
                'CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH' =>
                    '/tsa-worker-private-key'
            ))

        execute_command(
            "echo \"#{tsa_public_key}\" > /tsa-public-key")
        execute_command(
            "echo \"#{tsa_worker_private_key}\" > /tsa-worker-private-key")

        execute_docker_entrypoint(
            started_indicator: "guardian.started")
      end

      after(:all, &:reset_docker_backend)

      it 'uses the provided file path as the TSA public key' do
        expect(process('concourse').args)
            .to(match(
                /--tsa-public-key=\/tsa-public-key/))
      end

      it 'uses the provided file path as the TSA worker private key' do
        expect(process('concourse').args)
            .to(match(
                /--tsa-worker-private-key=\/tsa-worker-private-key/))
      end
    end

    context 'when passed object paths for the public key and worker ' +
        'private key' do
      def tsa_public_key
        File.read('spec/fixtures/tsa-host-key.public')
      end

      def tsa_worker_private_key
        File.read('spec/fixtures/worker-key.private')
      end

      before(:all) do
        tsa_public_key_object_path =
            "#{s3_bucket_path}/tsa-public-key"
        tsa_worker_private_key_object_path =
            "#{s3_bucket_path}/tsa-worker-private-key"

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: tsa_public_key_object_path,
            content: tsa_public_key)

        create_object(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: tsa_worker_private_key_object_path,
            content: tsa_worker_private_key)

        create_env_file(
            endpoint_url: s3_endpoint_url,
            region: s3_bucket_region,
            bucket_path: s3_bucket_path,
            object_path: s3_env_file_object_path,
            env: default_env.merge(
                'CONCOURSE_TSA_PUBLIC_KEY_FILE_OBJECT_PATH' =>
                    tsa_public_key_object_path,
                'CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_OBJECT_PATH' =>
                    tsa_worker_private_key_object_path
            ))

        execute_docker_entrypoint(
            started_indicator: "guardian.started")
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the specified TSA public key and TSA worker private key' do
        config_file_listing = command('ls /opt/concourse/conf').stdout

        expect(config_file_listing)
            .to(eq([
                "tsa-public-key",
                "tsa-worker-private-key",
            ].join("\n") + "\n"))

        tsa_public_key_path = '/opt/concourse/conf/tsa-public-key'
        tsa_public_key_contents =
            command("cat #{tsa_public_key_path}").stdout

        tsa_worker_private_key_path =
            '/opt/concourse/conf/tsa-worker-private-key'
        tsa_worker_private_key_contents =
            command("cat #{tsa_worker_private_key_path}").stdout

        expect(tsa_public_key_contents).to(eq(tsa_public_key))
        expect(tsa_worker_private_key_contents).to(eq(tsa_worker_private_key))
      end

      it 'uses the fetched TSA public key' do
        key_path = '/opt/concourse/conf/tsa-public-key'
        expect(process('concourse').args)
            .to(match(
                /--tsa-public-key=#{Regexp.escape(key_path)}/))
      end

      it 'uses the fetched TSA worker private key' do
        key_path = '/opt/concourse/conf/tsa-worker-private-key'
        expect(process('concourse').args)
            .to(match(
                /--tsa-worker-private-key=#{Regexp.escape(key_path)}/))
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