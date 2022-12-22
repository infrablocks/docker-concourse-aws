# frozen_string_literal: true

require 'spec_helper'

describe 'concourse-worker-aws entrypoint' do
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
    'concourse-worker-aws:latest'
  end

  def extra
    {
      'Entrypoint' => '/bin/sh',
      'HostConfig' => {
        'Privileged' => true,
        'NetworkMode' => 'docker_concourse_aws_test_default'
      }
    }
  end

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

    def tsa_worker_private_key_file_path
      '/tsa-worker-private-key'
    end

    before(:all) do
      create_env_file(
        endpoint_url: s3_endpoint_url,
        region: s3_bucket_region,
        bucket_path: s3_bucket_path,
        object_path: s3_env_file_object_path,
        env: {
          'CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH' =>
            tsa_worker_private_key_file_path
        }
      )

      write_file(tsa_worker_private_key, tsa_worker_private_key_file_path)

      execute_docker_entrypoint(
        started_indicator: 'baggageclaim.listening'
      )
    end

    after(:all, &:reset_docker_backend)

    it 'runs the concourse binary' do
      expect(process('concourse')).to(be_running)
    end

    it 'runs the worker subcommand of the concourse binary' do
      expect(process('concourse').args).to(match(/worker/))
    end

    it 'uses the instance ID as the worker name' do
      expect(process('concourse').args)
        .to(match(/--name=i-1234567890abcdef0/))
    end

    it 'uses a work directory of /var/opt/concourse' do
      expect(process('concourse').args)
        .to(match(%r{--work-dir=/var/opt/concourse}))
    end

    it 'uses a bind IP of 0.0.0.0' do
      expect(process('concourse').args)
        .to(match(/--bind-ip=0\.0\.0\.0/))
    end

    it 'uses a baggageclaim bind IP of 0.0.0.0' do
      expect(process('concourse').args)
        .to(match(/--baggageclaim-bind-ip=0\.0\.0\.0/))
    end

    it 'uses a garden DNS server of 169.254.169.253' do
      pid = process('concourse').pid
      environment_contents =
        command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout

      expect(environment_contents)
        .to(match(/^CONCOURSE_GARDEN_DNS_SERVER=169.254.169.253/))
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
    def tsa_worker_private_key
      File.read('spec/fixtures/worker-key.private')
    end

    def tsa_worker_private_key_file_path
      '/tsa-worker-private-key'
    end

    before(:all) do
      create_env_file(
        endpoint_url: s3_endpoint_url,
        region: s3_bucket_region,
        bucket_path: s3_bucket_path,
        object_path: s3_env_file_object_path,
        env: {
          'CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH' =>
            tsa_worker_private_key_file_path,
          'CONCOURSE_NAME' => 'worker-1',
          'CONCOURSE_WORK_DIR' => '/work',
          'CONCOURSE_BIND_IP' => '127.0.0.1',
          'CONCOURSE_BAGGAGECLAIM_BIND_IP' => '127.0.0.1',
          'CONCOURSE_SKIP_GARDEN_DNS_SERVER' => 'yes'
        }
      )

      write_file(tsa_worker_private_key, tsa_worker_private_key_file_path)

      execute_docker_entrypoint(
        started_indicator: 'baggageclaim.listening'
      )
    end

    after(:all, &:reset_docker_backend)

    it 'uses the provided name' do
      expect(process('concourse').args)
        .to(match(/--name=worker-1/))
    end

    it 'uses the provided work directory' do
      expect(process('concourse').args)
        .to(match(%r{--work-dir=/work}))
    end

    it 'uses the provided bind IP' do
      expect(process('concourse').args)
        .to(match(/--bind-ip=127\.0\.0\.1/))
    end

    it 'uses the provided baggageclaim bind IP' do
      expect(process('concourse').args)
        .to(match(/--baggageclaim-bind-ip=127\.0\.0\.1/))
    end

    it 'does not set a garden DNS server' do
      pid = process('concourse').pid
      environment_contents =
        command("tr '\\0' '\\n' < /proc/#{pid}/environ").stdout

      expect(environment_contents)
        .not_to(match(/CONCOURSE_GARDEN_DNS_SERVER/))
    end
  end

  describe 'with TSA configuration' do
    context 'when passed filesystem paths for the public key and worker ' \
            'private key' do
      def tsa_public_key
        File.read('spec/fixtures/tsa-host-key.public')
      end

      def tsa_worker_private_key
        File.read('spec/fixtures/worker-key.private')
      end

      def tsa_public_key_file_path
        '/tsa-public-key'
      end

      def tsa_worker_private_key_file_path
        '/tsa-worker-private-key'
      end

      before(:all) do
        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'CONCOURSE_TSA_PUBLIC_KEY_FILE_PATH' =>
              tsa_public_key_file_path,
            'CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_PATH' =>
              tsa_worker_private_key_file_path
          }
        )

        write_file(tsa_public_key, tsa_public_key_file_path)
        write_file(tsa_worker_private_key, tsa_worker_private_key_file_path)

        execute_docker_entrypoint(
          started_indicator: 'baggageclaim.listening'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'uses the provided file path as the TSA public key' do
        expect(process('concourse').args)
          .to(match(
                %r{--tsa-public-key=/tsa-public-key}
              ))
      end

      it 'uses the provided file path as the TSA worker private key' do
        expect(process('concourse').args)
          .to(match(
                %r{--tsa-worker-private-key=/tsa-worker-private-key}
              ))
      end
    end

    context 'when passed object paths for the public key and worker ' \
            'private key' do
      def tsa_public_key
        File.read('spec/fixtures/tsa-host-key.public')
      end

      def tsa_worker_private_key
        File.read('spec/fixtures/worker-key.private')
      end

      def tsa_public_key_object_path
        "#{s3_bucket_path}/tsa-public-key"
      end

      def tsa_worker_private_key_object_path
        "#{s3_bucket_path}/tsa-worker-private-key"
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
          tsa_public_key, tsa_public_key_object_path
        )
        create_object_in_bucket(
          tsa_worker_private_key, tsa_worker_private_key_object_path
        )

        create_env_file(
          endpoint_url: s3_endpoint_url,
          region: s3_bucket_region,
          bucket_path: s3_bucket_path,
          object_path: s3_env_file_object_path,
          env: {
            'CONCOURSE_TSA_PUBLIC_KEY_FILE_OBJECT_PATH' =>
              tsa_public_key_object_path,
            'CONCOURSE_TSA_WORKER_PRIVATE_KEY_FILE_OBJECT_PATH' =>
              tsa_worker_private_key_object_path
          }
        )

        execute_docker_entrypoint(
          started_indicator: 'baggageclaim.listening'
        )
      end

      after(:all, &:reset_docker_backend)

      it 'fetches the TSA public key and TSA worker private key' do
        config_file_listing = command('ls /opt/concourse/conf').stdout

        expect(config_file_listing)
          .to(eq("tsa-public-key\ntsa-worker-private-key\n"))
      end

      it 'fetches the correct TSA public key contents' do
        tsa_public_key_path = '/opt/concourse/conf/tsa-public-key'
        tsa_public_key_contents =
          command("cat #{tsa_public_key_path}").stdout

        expect(tsa_public_key_contents).to(eq(tsa_public_key))
      end

      it 'fetches the correct TSA worker private key contents' do
        tsa_worker_private_key_path =
          '/opt/concourse/conf/tsa-worker-private-key'
        tsa_worker_private_key_contents =
          command("cat #{tsa_worker_private_key_path}").stdout

        expect(tsa_worker_private_key_contents).to(eq(tsa_worker_private_key))
      end

      it 'uses the fetched TSA public key' do
        key_path = '/opt/concourse/conf/tsa-public-key'
        expect(process('concourse').args)
          .to(match(
                /--tsa-public-key=#{Regexp.escape(key_path)}/
              ))
      end

      it 'uses the fetched TSA worker private key' do
        key_path = '/opt/concourse/conf/tsa-worker-private-key'
        expect(process('concourse').args)
          .to(match(
                /--tsa-worker-private-key=#{Regexp.escape(key_path)}/
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
