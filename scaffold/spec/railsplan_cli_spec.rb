# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require_relative '../lib/synth/cli'

RSpec.describe Synth::CLI do
  let(:cli) { described_class.new }
  let(:tmpdir) { Dir.mktmpdir }
  
  before do
    # Change to temporary directory for tests
    @original_dir = Dir.pwd
    Dir.chdir(tmpdir)
  end
  
  after do
    Dir.chdir(@original_dir)
    FileUtils.rm_rf(tmpdir)
  end

  describe '#new' do
    it 'creates basic directory structure' do
      cli.new
      
      expect(Dir.exist?('app/models')).to be true
      expect(Dir.exist?('app/controllers')).to be true
      expect(Dir.exist?('config')).to be true
      expect(Dir.exist?('lib/templates/synth')).to be true
      expect(File.exist?('config/synth_modules.json')).to be true
      expect(File.exist?('.env.example')).to be true
    end
  end

  describe '#list' do
    before do
      cli.new # Set up basic structure
    end

    it 'shows no installed modules initially' do
      expect { cli.list }.to output(/Installed modules:\s+\(none\)/).to_stdout
    end

    it 'shows available modules' do
      expect { cli.list }.to output(/Available modules:/).to_stdout
    end
  end

  describe '#add' do
    before do
      cli.new # Set up basic structure
    end

    it 'installs a module successfully' do
      # Mock the modules_path to point to our test modules
      allow(cli).to receive(:modules_path).and_return(File.expand_path('../lib/templates/synth', __dir__))
      
      expect { cli.add('ai') }.to output(/Module 'ai' installed successfully/).to_stdout
      
      # Check that module is tracked as installed
      installed = JSON.parse(File.read('config/synth_modules.json'))
      expect(installed['installed']['ai']).to be_a(Hash)
      expect(installed['installed']['ai']['version']).to eq('1.0.0')
    end

    it 'fails gracefully for non-existent module' do
      expect { cli.add('nonexistent') }.to output(/Module 'nonexistent' not found/).to_stdout
                                       .and raise_error(SystemExit)
    end
  end

  describe '#doctor' do
    it 'reports missing directories' do
      expect { cli.doctor }.to output(/Missing directory/).to_stdout
    end

    it 'passes when structure is correct' do
      cli.new
      # Create .env file to satisfy doctor check
      File.write('.env', 'EXAMPLE=value')
      expect { cli.doctor }.to output(/All checks passed/).to_stdout
    end
  end

  describe '#scaffold' do
    before do
      cli.new
      # Mock AI module as installed
      modules_data = { 'installed' => { 'ai' => { 'version' => '1.0.0' } } }
      File.write('config/synth_modules.json', JSON.generate(modules_data))
    end

    it 'scaffolds an agent successfully' do
      expect { cli.scaffold('agent', 'testbot') }.to output(/Agent 'testbot' scaffolded successfully/).to_stdout
      
      expect(File.exist?('app/agents/testbot/testbot_agent.rb')).to be true
      expect(File.exist?('app/controllers/testbot_agents_controller.rb')).to be true
      expect(File.exist?('spec/agents/testbot_agent_spec.rb')).to be true
    end

    it 'requires AI module to be installed' do
      File.write('config/synth_modules.json', JSON.generate({ 'installed' => {} }))
      
      expect { cli.scaffold('agent', 'testbot') }.to output(/AI module is not installed/).to_stdout
    end
  end

  describe 'logging' do
    before do
      cli.new
    end

    it 'logs operations to synth.log' do
      allow(cli).to receive(:modules_path).and_return(File.expand_path('../lib/templates/synth', __dir__))
      
      cli.add('ai')
      
      expect(File.exist?('log/synth.log')).to be true
      log_content = File.read('log/synth.log')
      expect(log_content).to include('add_start')
      expect(log_content).to include('add_complete')
    end
  end
end