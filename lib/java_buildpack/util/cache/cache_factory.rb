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

require 'java_buildpack/util/cache'
require 'java_buildpack/util/cache/application_cache'
require 'java_buildpack/util/cache/download_cache'

module JavaBuildpack
  module Util
    module Cache

      # A factory for creating {DownloadCache}s.  Will create an {ApplicationCache} if it can, otherwise a
      # {DownloadCache}.
      class CacheFactory

        class << self
          @allowed_url_for_insecure_https = 'none'
          # Creates a new instance of an {ApplicationCache} if it can, otherwise a {DownloadCache}
          #
          # @return [ApplicationCache, DownloadCache] a new instance of an {ApplicationCache} if it can, otherwise a
          #                                           {DownloadCache}
          def create
            cache = if ApplicationCache.available?
                      ApplicationCache.new
                    else
                      DownloadCache.new(Pathname.new(Dir.tmpdir), \
                                        JavaBuildpack::Util::Cache::CACHED_RESOURCES_DIRECTORY)
                    end
            cache.allowed_url_for_unsafe_https = @allowed_url_for_insecure_https if cache.is_a? DownloadCache

            cache
          end

          # Allow download of file for server with self signed cert
          #
          #
          # @return [string] url
          def allowed_url(url)
            @allowed_url_for_insecure_https = url
          end
        end

      end

    end
  end
end
