require 'logger'

module Txgh
  class ResourceUpdater
    include Txgh::CategorySupport

    attr_reader :project, :repo, :logger

    def initialize(project, repo, logger = nil)
      @project = project
      @repo = repo
      @logger = logger || Logger.new(STDOUT)
    end

    # For each modified resource, get its content and update the content
    # in Transifex.
    def update_resource(tx_resource, commit_sha, categories = {})
      logger.info('process updated resource')
      tree_sha = repo.api.get_commit(repo.name, commit_sha)['commit']['tree']['sha']
      tree = repo.api.tree(repo.name, tree_sha)

      tree['tree'].each do |file|
        logger.info("process each tree entry: #{file['path']}")

        if tx_resource.source_file == file['path']
          if repo.upload_diffs?
            upload_diff(tx_resource, file)
          else
            upload_whole(tx_resource, file, categories)
          end
        end
      end
    end

    private

    def upload_whole(tx_resource, file, categories)
      content = contents_of(file['sha'])

      if repo.process_all_branches?
        upload_by_branch(tx_resource, content, categories)
      else
        upload(tx_resource, content)
      end
    end

    def upload_diff(tx_resource, file)
      if content = diff_content(tx_resource, file)
        upload_by_branch(tx_resource, content, categories_for(tx_resource))
      end
    end

    def diff_content(tx_resource, file)
      head_content = contents_of(file['sha'])
      diff_point_content = repo.api.download(
        repo.name, file['path'], repo.diff_point
      )

      DiffContentCalculator.diff_between(
        head_content, diff_point_content, tx_resource
      )
    end

    def upload(tx_resource, content)
      project.api.create_or_update(tx_resource, content)
    end

    def upload_by_branch(tx_resource, content, additional_categories)
      resource_exists = project.api.resource_exists?(tx_resource)
      categories = resource_exists ? categories_for(tx_resource) : {}
      categories.merge!(additional_categories)
      categories['branch'] ||= tx_resource.branch
      categories = serialize_categories(categories)

      if resource_exists
        project.api.update_details(tx_resource, categories: categories)
        project.api.update_content(tx_resource, content)
      else
        project.api.create(tx_resource, content, categories)
      end
    end

    def categories_for(tx_resource)
      resource = project.api.get_resource(*tx_resource.slugs)
      deserialize_categories(Array(resource['categories']))
    end

    def contents_of(sha)
      blob = repo.api.blob(repo.name, sha)

      if blob['encoding'] == 'utf-8'
        blob['content']
      else
        Base64.decode64(blob['content'])
      end
    end
  end
end
