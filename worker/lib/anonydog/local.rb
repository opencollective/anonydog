require 'ostruct'
require 'rugged'
require 'securerandom'

module Anonydog
  class Local
    def self.anonymize(opts)
      head_repo_clone_url = opts[:head][:clone_url]
      head_commit = opts[:head][:commit]

      base_repo_clone_url = opts[:base][:clone_url]
      base_commit = opts[:base][:commit]

      #TODO: use in-memory fs
      repo_path = "/tmp/#{SecureRandom.hex}"

      repo = Rugged::Repository.clone_at(
        head_repo_clone_url,
        repo_path)

      repo.remotes.create('upstream', base_repo_clone_url)
      repo.fetch('upstream')

      new_head = merge_base = repo.merge_base(head_commit, base_commit)
      
            Rugged::Walker.walk(
        repo,
        :sort => Rugged::SORT_TOPO | Rugged::SORT_REVERSE, # parents first
        :show => head_commit,
        :hide => merge_base) {
        |commit|
          fake_author_sig = {
            :name => 'Scooby Doo',
            :email => 'scooby@anonydog.org',
            :time => commit.author[:time]
          }

          current = Rugged::Commit.create(
            repo,
            :message => commit.message,
            :tree => commit.tree,
            # TODO: check for unintended side-effects here
            :committer => fake_author_sig,
            #TODO: inside a PR, can a commit have more than one parent?
            :parents => [new_head],
            :author => fake_author_sig
          )

          new_head = current
      }

      OpenStruct.new(:repo_path => repo_path, :head => new_head)
    end
  end
end