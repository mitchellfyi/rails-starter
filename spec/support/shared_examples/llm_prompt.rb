# frozen_string_literal: true

# Shared examples for LLM prompt-related functionality
# These examples test common patterns for models that handle prompts, templates, and context variables

RSpec.shared_examples 'a prompt with variables' do
  describe '#variable_names' do
    context 'when prompt contains variables' do
      it 'extracts variable names from {{variable}} syntax' do
        subject.prompt_text = 'Hello {{name}}, welcome to {{company}}!'
        expect(subject.variable_names).to contain_exactly('name', 'company')
      end

      it 'handles duplicate variables' do
        subject.prompt_text = 'Hello {{name}}, {{name}} is a great name for {{company}}'
        expect(subject.variable_names).to contain_exactly('name', 'company')
      end

      it 'handles variables with underscores and numbers' do
        subject.prompt_text = 'User {{user_name}} has {{total_count}} items'
        expect(subject.variable_names).to contain_exactly('user_name', 'total_count')
      end
    end

    context 'when prompt has no variables' do
      it 'returns empty array' do
        subject.prompt_text = 'This is a static prompt'
        expect(subject.variable_names).to eq([])
      end
    end
  end
end

RSpec.shared_examples 'a prompt with context rendering' do
  describe '#render_with_context' do
    before do
      subject.prompt_text = 'Hello {{name}}, welcome to {{company}}!'
    end

    context 'with complete context' do
      it 'renders all variables with string keys' do
        context = { 'name' => 'John', 'company' => 'Acme Corp' }
        result = subject.render_with_context(context)
        expect(result).to eq('Hello John, welcome to Acme Corp!')
      end

      it 'renders all variables with symbol keys' do
        context = { name: 'John', company: 'Acme Corp' }
        result = subject.render_with_context(context)
        expect(result).to eq('Hello John, welcome to Acme Corp!')
      end

      it 'handles mixed string and symbol keys' do
        context = { 'name' => 'John', company: 'Acme Corp' }
        result = subject.render_with_context(context)
        expect(result).to eq('Hello John, welcome to Acme Corp!')
      end
    end

    context 'with incomplete context' do
      it 'replaces missing variables with empty string' do
        context = { 'name' => 'John' }
        result = subject.render_with_context(context)
        expect(result).to eq('Hello John, welcome to !')
      end
    end

    context 'with empty context' do
      it 'replaces all variables with empty strings' do
        result = subject.render_with_context({})
        expect(result).to eq('Hello , welcome to !')
      end
    end

    context 'with additional context variables' do
      it 'ignores unused variables' do
        context = { 'name' => 'John', 'company' => 'Acme', 'unused' => 'value' }
        result = subject.render_with_context(context)
        expect(result).to eq('Hello John, welcome to Acme!')
      end
    end

    context 'with special characters in values' do
      it 'handles special characters in variable values' do
        context = { 'name' => 'John & Jane', 'company' => 'Acme <Corp>' }
        result = subject.render_with_context(context)
        expect(result).to eq('Hello John & Jane, welcome to Acme <Corp>!')
      end
    end
  end
end

RSpec.shared_examples 'a prompt with validation' do
  describe 'validations' do
    it 'requires prompt_text' do
      subject.prompt_text = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:prompt_text]).to include("can't be blank")
    end

    it 'requires name' do
      subject.name = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:name]).to include("can't be blank")
    end

    context 'when slug is present' do
      it 'validates slug format' do
        subject.slug = 'invalid slug!'
        expect(subject).not_to be_valid
        expect(subject.errors[:slug]).to include('is invalid')
      end

      it 'allows valid slug formats' do
        valid_slugs = ['valid-slug', 'valid_slug', 'slug123', 'valid-slug-123']
        valid_slugs.each do |slug|
          subject.slug = slug
          expect(subject).to be_valid, "Expected '#{slug}' to be valid"
        end
      end
    end
  end
end

RSpec.shared_examples 'a prompt with slug generation' do
  describe 'slug generation' do
    context 'when slug is blank' do
      it 'generates slug from name' do
        subject.name = 'My Test Prompt'
        subject.slug = nil
        subject.valid? # Trigger validations and callbacks
        expect(subject.slug).to eq('my_test_prompt')
      end

      it 'handles special characters in name' do
        subject.name = 'Test Prompt! With @#$ Special Characters'
        subject.slug = nil
        subject.valid?
        expect(subject.slug).to eq('test_prompt_with_special_characters')
      end

      it 'handles leading and trailing whitespace' do
        subject.name = '  Test Prompt  '
        subject.slug = nil
        subject.valid?
        expect(subject.slug).to eq('test_prompt')
      end
    end

    context 'when slug is already present' do
      it 'does not overwrite existing slug' do
        subject.name = 'New Name'
        subject.slug = 'existing-slug'
        subject.valid?
        expect(subject.slug).to eq('existing-slug')
      end
    end
  end
end

RSpec.shared_examples 'a versioned prompt' do
  describe 'versioning' do
    it 'sets initial version when blank' do
      subject.version = nil
      subject.valid?
      expect(subject.version).to eq('1.0.0')
    end

    it 'validates version format' do
      subject.version = 'invalid'
      expect(subject).not_to be_valid
      expect(subject.errors[:version]).to include('is invalid')
    end

    it 'allows valid version formats' do
      valid_versions = ['1.0.0', '1.2.3', '10.20.30']
      valid_versions.each do |version|
        subject.version = version
        expect(subject).to be_valid, "Expected version '#{version}' to be valid"
      end
    end
  end

  describe '#create_new_version!' do
    before do
      subject.save! if subject.new_record?
    end

    it 'creates a new version with incremented version number' do
      subject.version = '1.0.0'
      new_version = subject.create_new_version!
      expect(new_version.version).to eq('1.0.1')
      expect(new_version.name).to eq(subject.name)
      expect(new_version.prompt_text).to eq(subject.prompt_text)
    end

    it 'starts new versions as draft' do
      new_version = subject.create_new_version!
      expect(new_version.status).to eq('draft')
    end

    it 'allows custom attributes' do
      new_version = subject.create_new_version!(prompt_text: 'Updated prompt')
      expect(new_version.prompt_text).to eq('Updated prompt')
    end
  end

  describe '#latest_version?' do
    before do
      subject.save! if subject.new_record?
    end

    it 'returns true for single version' do
      expect(subject.latest_version?).to be true
    end

    it 'returns true for the most recent version' do
      older_version = subject
      newer_version = subject.create_new_version!
      
      expect(newer_version.latest_version?).to be true
      expect(older_version.latest_version?).to be false
    end
  end
end

RSpec.shared_examples 'a prompt with context validation' do
  describe '#validate_context' do
    before do
      subject.prompt_text = 'Hello {{name}}, welcome to {{company}}!'
    end

    it 'returns true when all variables are provided' do
      context = { 'name' => 'John', 'company' => 'Acme' }
      expect(subject.validate_context(context)).to be true
    end

    it 'returns array of missing variables when context is incomplete' do
      context = { 'name' => 'John' }
      missing = subject.validate_context(context)
      expect(missing).to eq(['company'])
    end

    it 'returns all variables when context is empty' do
      missing = subject.validate_context({})
      expect(missing).to contain_exactly('name', 'company')
    end

    it 'works with symbol keys' do
      context = { name: 'John', company: 'Acme' }
      expect(subject.validate_context(context)).to be true
    end
  end
end