require 'spec_helper'

include Txgh

describe TxBranchResource do
  let(:resource_slug) { 'resource_slug' }
  let(:resource_slug_with_branch) { "#{resource_slug}-heads_my_branch" }
  let(:project_slug) { 'project_slug' }
  let(:branch) { 'heads/my_branch' }

  let(:api) { :api }
  let(:config) { { name: project_slug } }
  let(:resources) { [base_resource] }

  let(:tx_config) do
    TxConfig.new(resources, {})
  end

  let(:project) do
    TransifexProject.new(config, tx_config, api)
  end

  let(:base_resource) do
    TxResource.new(
      project_slug, resource_slug, 'type', 'source_lang', 'source_file',
      'ko-KR:ko', 'translation_file'
    )
  end

  describe '.find' do
    it 'finds the correct resource' do
      resource = TxBranchResource.find(project, resource_slug_with_branch, branch)
      expect(resource).to be_a(TxBranchResource)
      expect(resource.resource).to eq(base_resource)
      expect(resource.branch).to eq(branch)
    end

    it 'returns nil if no resource matches' do
      resource = TxBranchResource.find(project, 'foobar', branch)
      expect(resource).to be_nil

      resource = TxBranchResource.find(project, resource_slug_with_branch, 'foobar')
      expect(resource).to be_nil
    end
  end

  context 'with a resource' do
    let(:resource) do
      TxBranchResource.new(base_resource, branch)
    end

    describe '#resource_slug' do
      it 'adds the branch name to the resource slug' do
        expect(resource.resource.resource_slug).to eq(resource_slug)
        expect(resource.resource_slug).to eq(resource_slug_with_branch)
      end
    end
  end
end
