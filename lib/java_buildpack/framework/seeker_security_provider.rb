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
require 'net/http'
require 'json'
require 'date'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for enabling zero-touch Seeker support.
    class SeekerSecurityProvider < JavaBuildpack::Component::BaseComponent
      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        @application.services.one_service? FILTER
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)

      def compile
        puts 'version 4'
        credentials = fetch_credentials
        assert_configuration_valid(credentials)
        if should_download_sensor(credentials[ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY])
          fetch_agent_within_sensor(credentials)
        else
          fetch_agent_direct(credentials)
        end
        @droplet.copy_resources
      end

      # extract seeker relevant configuration as map
      def fetch_credentials
        service = @application.services.find_service FILTER, SENSOR_HOST_SERVICE_CONFIG_KEY
        service['credentials']
      end

      # verify required agent configuration is present
      def assert_configuration_valid(credentials)
        mandatory_config_keys =
          [ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY, SENSOR_HOST_SERVICE_CONFIG_KEY,
           SENSOR_PORT_SERVICE_CONFIG_KEY]
        mandatory_config_keys.each do |config_key|
          raise "'#{config_key}' credential must be set" unless credentials[config_key]
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        credentials = fetch_credentials
        @droplet.java_opts.add_javaagent(@droplet.sandbox + 'seeker-agent.jar')
        @droplet.environment_variables
                .add_environment_variable('SEEKER_SENSOR_HOST', credentials[SENSOR_HOST_SERVICE_CONFIG_KEY])
                .add_environment_variable('SEEKER_SENSOR_HTTP_PORT', credentials[SENSOR_PORT_SERVICE_CONFIG_KEY])
      end

      # JSON key for the host of the seeker sensor
      SENSOR_HOST_SERVICE_CONFIG_KEY = 'sensor_host'

      # JSON key for the port of the seeker sensor
      SENSOR_PORT_SERVICE_CONFIG_KEY = 'sensor_port'

      # Enterprise server url, for example: `https://seeker-server.com:8082`
      ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY = 'enterprise_server_url'

      # Relative path of the sensor zip
      SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER = 'rest/ui/installers/binaries/LINUX'

      # Relative path of the Java agent jars after Sensor extraction
      AGENT_JARS_PATH = 'inline/agents/java/*'

      # Relative path of the agent zip
      AGENT_PATH = '/rest/ui/installers/agents/binaries/JAVA'

      # Version details of Seekers server REST API path
      SEEKER_VERSION_API = '/rest/api/version'

      # seeker service name identifier
      FILTER = /seeker/

      private_constant :SENSOR_HOST_SERVICE_CONFIG_KEY, :SENSOR_PORT_SERVICE_CONFIG_KEY,
                       :ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY, :SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER,
                       :AGENT_JARS_PATH, :AGENT_PATH, :SEEKER_VERSION_API

      private

      def should_download_sensor(server_base_url)
        version_address = URI.join(server_base_url, SEEKER_VERSION_API).to_s
        escaped_address = URI.escape(version_address)
        uri = URI.parse(escaped_address)
        json_response = Net::HTTP.get(uri)
        puts "Seeker server response for version WS: #{json_response}"
        seeker_version_response = JSON.parse(json_response)
        seeker_version = seeker_version_response['version']
        version_prefix = seeker_version[0, 7]
        last_seeker_version_without_agent_direct_download_date = Date.parse('2018.05.01')
        puts "Current Seeker version #{version_prefix}"
        version_date = Date.parse(version_prefix + '.01')
        version_date > last_seeker_version_without_agent_direct_download_date
      end

      def agent_direct_link(credentials)
        URI.join(credentials[ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY], AGENT_PATH).to_s
      end

      def fetch_agent_direct(credentials)
        puts 'Trying to download agent directly...'
        java_agent_zip_uri = agent_direct_link(credentials)
        puts "Before downloading Agent from: #{java_agent_zip_uri}"
        download_zip('', java_agent_zip_uri, false, @droplet.sandbox)
      end

      def fetch_agent_within_sensor(credentials)
        puts 'Trying to download sensor...'
        seeker_tmp_dir = @droplet.sandbox + 'seeker_tmp_sensor'
        shell "rm -rf #{seeker_tmp_dir}"
        enterprise_server_uri = URI.parse(
          URI.encode(credentials[ENTERPRISE_SERVER_URL_SERVICE_CONFIG_KEY].strip)
        )
        puts "Before downloading Sensor from: #{enterprise_server_uri}"
        download_zip('', URI.join(enterprise_server_uri,
                                  SENSOR_ZIP_RELATIVE_PATH_AT_ENTERPRISE_SERVER).to_s,
                     false, seeker_tmp_dir, 'SensorInstaller.zip')
        inner_jar_file = seeker_tmp_dir + 'SeekerInstaller.jar'
        # Unzip only the java agent - to save time
        shell "unzip -j #{inner_jar_file} #{AGENT_JARS_PATH} -d #{@droplet.sandbox} 2>&1"
        shell "rm -rf #{seeker_tmp_dir}"
      end
    end
  end
end
