# redMine - project management software (ruby-lang.org edition)
# Copyright (C) 2006-2007  Jean-Philippe Lang
# Copyright (C) 2008 Yuki Sonoda (Yugui)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine/scm/adapters/abstract_adapter'
require 'open-uri'
require 'hpricot'

module Redmine
  module Scm
    module Adapters    
      class GithubAdapter < AbstractAdapter
        GITHUB_HOST = 'github.com'
        GITHUB_API_HOST = 'github.com'
        GITHUB_API_SCHEME = 'http'
        def initialize(url, root_url=nil, login=nil, password=nil)
          @revision_cache = {}

          case url
          when %r[\Agit://#{GITHUB_HOST}/([\w-]+)/([\w-]+)\.git\z]
            @repos_owner, @project = $1, $2
          when %r[\Ahttp://#{GITHUB_HOST}/([\w-]+)/([\w-]+)\z]
            @repos_owner, @project = $1, $2
          else
            raise ArgumentError, "Unrecognized repository URI: #{url}"
          end

          git_uri = URI::Generic.build(:scheme => 'git', :host => GITHUB_HOST, :path => "/#{@repos_owner}/#{@project}.git")
          super(git_uri.to_s, nil, login, password)
        end

        def adapter_name
          'Github'
        end
        
        def info
          logger.debug('GithubAdapter#info')
          last_rev = retrieve_commit('master')
          return Info.new :root_url => self.url, :lastrev => last_rev
        end

        def entries(path = nil, identifier = nil)
          logger.debug("GithubAdapter#entries(#{path.inspect}, #{identifier.inspect}")
          path ||= ''; identifier ||= 'master'
          entries = Entries.new
          path = path[1..-1] if path && path.starts_with?('/')
          uri = "http://#{GITHUB_HOST}/#{@repos_owner}/#{@project}/tree/#{identifier}/#{path}"
          open(uri){|io|
            doc = Hpricot(io)
            (doc/'#browser'/:table/:tr/'td[2]'/:a/'text()').each do |text|
              text = text.to_s
              next if text == '..'

              entry_path = File.join(path, text)
              entry_path = entry_path[1..-1] if entry_path && entry_path.starts_with?('/')
              entry = Entry.new :name => text, :path => entry_path,
                :kind => (text.ends_with?('/') ? 'dir' : 'file'),
                :size => (text.ends_with?('/') ? nil : file_size(entry_path, identifier)),
                :lastrev => last_rev(entry_path, identifier)
              entries << entry
            end
          }
          logger.debug("Found #{entries.size} entries in the repository for #{uri}") if logger && logger.debug?
          entries.sort_by_name
        end

        def revisions(path=nil, identifier_from=nil, identifier_to=nil, options={})
          logger.debug("GithubAdapter#revisions(#{path.inspect}, #{identifier.inspect}")
          identifier_to ||= 'master'
          path = path[1..-1] if path && path.starts_with?('/')
          retval = options[:revisions] || Revisions.new
          #return retval if retval.length > 10

          rev = retrieve_commit(identifier_to)
          retval << rev if rev.paths.any?{|entry| entry[:path].starts_with?(path)}
          rev.parent_ids.each do |id|
            revisions(path, identifier_from, id, :revisions => retval)
          end
          return retval
        end

        def diff(path, identifier_from, identifier_to=nil, type="inline")
          raise NotImplementedError, "diff will be implemented soon"
        end

        def cat(path, identifier=nil)
          logger.debug("GithubAdapter#cat(#{path.inspect}, #{identifier.inspect}")
          path ||= ''; identifier ||= 'master'
          path = "/#{path}" unless path[0]==?/
          uri = "http://#{GITHUB_HOST}/#{@repos_owner}/#{@project}/tree/#{identifier}#{path}?raw=true"
          open(uri){|io| return io.read }
        end

        private
        def retrieve_commits(to)
          uri_path = "/api/v1/xml/#{@repos_owner}/#{@project}/commits/#{to}"
          uri = URI::Generic.build(:scheme => GITHUB_API_SCHEME, :host => GITHUB_API_HOST, :path => uri_path)
          open(uri.to_s){|io|
            doc = REXML::Document.new(REXML::IOSource.new(io))
            return doc.get_elements('/commits/commit').map{|elm| reivision_from_element(elm) }
          }
        end
        def retrieve_commit(commit_id = nil)
          return @revision_cache[commit_id] if /\A[0-9A-Fa-f]{40}\z/ =~ commit_id && @revision_cache[commit_id]

          commit_id ||= 'master'
          uri_path = "/api/v1/xml/#{@repos_owner}/#{@project}/commit/#{commit_id}"
          uri = URI::Generic.build(:scheme => GITHUB_API_SCHEME, :host => GITHUB_API_HOST, :path => uri_path)

          open(uri.to_s){|io|
            doc = REXML::Document.new(REXML::IOSource.new(io))
            rev = reivision_from_commit_element(doc.root)
            logger.info("retrieving #{rev.identifier} : #{rev.time.to_s :db}")
            return @revision_cache[rev.identifier] = rev
          }
        end
        def reivision_from_commit_element(commit)
          id = commit.elements['id'].text

          paths = []
          %w[ added deleted modified ].each do |action|
            filenames = commit.get_elements("#{action}/#{action}/filename")
            paths += filenames.map {|filename| {:action => action, :path => filename.text} }
          end
          parent_ids = commit.get_elements('parents/parent/id').map(&:text)

          rev = Revision.new :identifier => id, :scmid => id,
            :author => commit.elements['committer/name'].text,
            :time => Time.parse(commit.elements['committed-date'].text).localtime,
            :message => commit.elements['message'].text,
            :paths => paths,
            :parent_ids => parent_ids
          return rev
        end

        def last_rev(path, identifier)
          path = path[1..-1] if path && path.starts_with?('/')
          url = "http://github.com/feeds/#{@repos_owner}/commits/#{@project}/#{identifier}/#{path}"
          open(url){|io|
            doc = REXML::Document.new(REXML::IOSource.new(io))
            entry = doc.elements['/feed/entry']
            id = entry.elements['id'].text[/[0-9A-Fa-f]{40}$/]
            #return retrieve_commit(id)
            return Revision.new :identifier => id, :scmid => id,
              :author => entry.elements['author/name'].text,
              :time => Time.parse(entry.elements['updated'].text).localtime,
              :message => entry.elements['title']
          }
        end
        def file_size(path, identifier)
          path = path[1..-1] if path && path.starts_with?('/')
          Net::HTTP.start(GITHUB_HOST){|conn|
            response = conn.head("/#{@repos_owner}/#{@project}/tree/#{identifier}/#{path}?raw=true")
            return response['content-length'] && response['content-length'].to_i
          }
        end

        class Revision < Redmine::Scm::Adapters::Revision
          attr_reader :parent_ids
          def initialize(hash)
            @parent_ids = hash[:parent_ids]
            super
          end
        end
      end
    end
  end
end
