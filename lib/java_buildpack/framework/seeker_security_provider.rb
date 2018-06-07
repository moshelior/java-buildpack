# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'fileutils'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Seeker support.
    class SeekerSecurityProvider < JavaBuildpack::Component::BaseComponent
      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        true
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        credentials = fetch_credentials
        assert_configuration_valid(credentials)
        absolute_sensor_dir = File.join(@droplet.sandbox, 'seeker_tmp_sensor/')
        FileUtils.mkdir_p absolute_sensor_dir
        puts "Sensor Directory: #{absolute_sensor_dir}"
        shell "rm -rf #{absolute_sensor_dir}"
        puts 'After deletion of sesnro dir'
        enterprise_server_uri  = URI.parse(URI.encode(credentials[ENTERPRISE_SERVER_URI_SERVICE_CONFIG_KEY].strip))
        puts "Before downloading from: #{enterprise_server_uri}"
        puts "realtive dir : #{@droplet.sandbox + 'seeker_tmp_sensor/'} and ansolute: #{absolute_sensor_dir}"
        download_zip('', URI.join(enterprise_server_uri,
                                  SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER).to_s, false, @droplet.sandbox + 'seeker_tmp_sensor', 'SensorInstaller.zip')
        puts 'Doen downloading '
        # aaa =  `ls -lrt #{absolute_sensor_dir}`
        # puts "#{aaa}"
        # shell "unzip  #{File.join(absolute_sensor_dir, 'SensorInstaller.jar')}  "
        # puts 'Aftger unzip 1'
        shell "unzip  #{File.join(absolute_sensor_dir, 'SeekerInstaller.jar')} #{AGENT_JARS_PATH} -d #{absolute_sensor_dir} 2>&1"
        puts 'Aftger unzip 2'
        shell "rm -rf #{absolute_sensor_dir}"
        puts 'Aftger cleanup'
        @droplet.copy_resources
        puts 'Aftger cop resrouces'
      end

      # extract seeker relevant configuration as map
      def fetch_credentials
        service = @application.services.find_service FILTER, SEEKER_HOST_SERVICE_CONFIG_KEY
        service['credentials']
      end

      # verify required agent configuration is present
      def assert_configuration_valid(credentials)
        mandatory_config_keys =
          [ENTERPRISE_SERVER_URI_SERVICE_CONFIG_KEY, SEEKER_HOST_SERVICE_CONFIG_KEY,
           SEEKER_HOST_PORT_SERVICE_CONFIG_KEY]
        mandatory_config_keys.each do |config_key|
          raise "'#{config_key}' credential must be set" unless credentials[config_key]
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = fetch_credentials
        @droplet.java_opts.add_javaagent(@droplet.sandbox + 'seeker-agent.jar')
        @droplet.environment_variables
                .add_environment_variable('SEEKER_SENSOR_HOST', credentials[SEEKER_HOST_SERVICE_CONFIG_KEY])
                .add_environment_variable('SEEKER_SENSOR_HTTP_PORT', credentials[SEEKER_HOST_PORT_SERVICE_CONFIG_KEY])
      end

      # JSON key for the host of the seeker sensor
      SEEKER_HOST_SERVICE_CONFIG_KEY = 'sensor_host'

      # JSON key for the port of the seeker sensor
      SEEKER_HOST_PORT_SERVICE_CONFIG_KEY = 'sensor_port'

      # Enterprise server uri, for example: `https://seeker-server.com:8082`
      ENTERPRISE_SERVER_URI_SERVICE_CONFIG_KEY = 'enterprise_server_uri'

      # Relative path of the sensor zip
      SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER = 'rest/ui/installers/binaries/LINUX/SensorInstaller.zip' # TODO: remove after the last slash - used for testing

      # Relative path of the agent jars after Sensor extraction
      AGENT_JARS_PATH = 'inline/agents/java/'

      # seeker service name identifier
      FILTER = /seeker/

      private_constant :SEEKER_HOST_SERVICE_CONFIG_KEY, :SEEKER_HOST_PORT_SERVICE_CONFIG_KEY,
                       :ENTERPRISE_SERVER_URI_SERVICE_CONFIG_KEY, :SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER,
                       :AGENT_JARS_PATH
    end
  end
end
