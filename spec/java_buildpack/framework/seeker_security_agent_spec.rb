# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

require 'spec_helper'
require 'component_helper'
require 'java_buildpack/framework/seeker_security_provider'

describe JavaBuildpack::Framework::SeekerSecurityProvider do
  include_context 'with component help'

  let(:configuration) do
    { 'some_property' => nil }
  end

  it 'does not detect without seeker service' do
    expect(component.detect).to be_falsey
  end

  context do

    let(:credentials) { {} }

    before do
      allow(services).to receive(:one_service?).with(/seeker/).and_return(true)
      allow(services).to receive(:find_service).and_return('credentials' => credentials)
    end

    it 'detects with seeker service' do
      expect(component.detect).to be_truthy
    end

    context do
      let(:credentials) do
        { 'sensor_port' => '9911',
          'sensor_host' => 'localhost' }
      end

      it 'raises error if `enterprise_server_url` not specified' do
        expect { component.compile }.to raise_error(/'enterprise_server_url' credential must be set/)
      end
    end

    context do
      let(:credentials) do
        { 'enterprise_server_url' => 'http://10.120.9.45:8082',
          'sensor_port'           => '9911' }
      end

      it 'raises error if `sensor_host` not specified' do
        expect { component.compile }.to raise_error(/'sensor_host' credential must be set/)
      end

    end
    context do
      let(:credentials) do
        { 'enterprise_server_url' => 'http://10.120.9.45:8082',
          'sensor_host'           => 'localhost' }
      end

      it 'raises error if `sensor_port` not specified' do
        expect { component.compile }.to raise_error(/'sensor_port' credential must be set/)
      end

    end

    context do

      let(:credentials) do
        { 'enterprise_server_url' => 'http://10.120.9.45:8082',
          'sensor_host'           => 'localhost',
          'sensor_port'           => '9911' }
      end

      before do
        allow(component).to receive(:agent_direct_link).with(credentials).and_return('test-uri')
      end
      it 'expands Seeker agent zip',
         cache_fixture: 'seeker-java-agent.zip' do

        component.compile

        expect(sandbox + 'seeker-agent.jar').to exist

      end
      it 'updates JAVA_OPTS' do
        component.release

        expect(java_opts).to include('-javaagent:$PWD/.java-buildpack/seeker_security_provider/seeker-agent.jar')
      end

    end

  end

end
