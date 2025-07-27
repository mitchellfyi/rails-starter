# Workspace-Scoped Fine-Tuning Support

This implementation adds comprehensive workspace-scoped fine-tuning support to the Rails SaaS Starter Template, enabling teams to upload and manage their own training or embedding data for AI customization.

## Features Implemented

### 🎯 Core Models

#### AiDataset Model
- **File Management**: Upload and manage training/embedding data files
- **Processing Status**: Track processing state (pending, processing, completed, failed)
- **Dataset Types**: Support for both embedding and fine-tuning datasets
- **Workspace Scoping**: All datasets belong to specific workspaces
- **File Upload**: Built-in support for multiple file formats (.txt, .md, .json, .csv)
- **Processing Logic**: Automatic chunking and embedding generation for RAG

#### WorkspaceEmbeddingSource Model
- **Multiple Source Types**: Dataset, context fetcher, semantic memory, external API, manual
- **Status Management**: Active/inactive status with testing capabilities
- **Configuration**: JSON-based configuration for different source types
- **Integration**: Links to AiDataset for dataset-based sources
- **Testing**: Built-in connection testing and refresh capabilities

#### WorkspaceAiConfig Model
- **RAG Configuration**: Complete retrieval-augmented generation settings
- **Model Selection**: Configurable chat and embedding models
- **Instructions System**: Workspace-level AI instructions (like Cursor/ChatGPT settings)
- **Advanced Settings**: Temperature, max tokens, penalties, and more
- **Tools Configuration**: Enable/disable AI tools and functions

### 🚀 Services

#### OpenaiFineTuningService
- **Fine-Tuning Integration**: Complete OpenAI fine-tuning API integration
- **Job Management**: Create, monitor, and manage fine-tuning jobs
- **Model Deployment**: Deploy and use fine-tuned models
- **File Validation**: Validate training data format for fine-tuning
- **Mock Implementation**: Development-friendly mock client for testing

### 🎨 User Interface

#### Dataset Management
- **List View**: Filter by type and status, file count and size display
- **Detail View**: Complete dataset information with file management
- **Upload Form**: Multi-file upload with format validation
- **Processing Actions**: Process datasets, check status, download files

#### Embedding Sources
- **Source Management**: Create and configure different source types
- **Testing Interface**: Test connections and refresh embeddings
- **Status Monitoring**: Real-time status updates and error handling

#### AI Configuration
- **Settings Panel**: Comprehensive AI model and RAG configuration
- **Live Testing**: Test RAG retrieval with sample queries
- **Instructions Editor**: Rich text editor for workspace AI instructions
- **Model Selection**: Dropdown selection for available models

### 🔧 Technical Implementation

#### Database Schema
```ruby
# AI Datasets
create_table :ai_datasets do |t|
  t.string :name, null: false
  t.text :description
  t.string :dataset_type, null: false # 'embedding', 'fine-tune'
  t.string :processed_status, null: false, default: 'pending'
  t.datetime :processed_at
  t.text :error_message
  t.json :metadata, default: {}
  t.references :workspace, null: false, foreign_key: true
  t.references :created_by, null: false, foreign_key: { to_table: :users }
  t.timestamps
end

# Workspace Embedding Sources
create_table :workspace_embedding_sources do |t|
  t.string :name, null: false
  t.text :description
  t.string :source_type, null: false # 'dataset', 'context_fetcher', etc.
  t.string :status, null: false, default: 'inactive'
  t.json :config, default: {}
  t.datetime :last_tested_at
  t.references :workspace, null: false, foreign_key: true
  t.references :ai_dataset, null: true, foreign_key: true
  t.references :created_by, null: false, foreign_key: { to_table: :users }
  t.timestamps
end

# Workspace AI Configurations
create_table :workspace_ai_configs do |t|
  t.text :instructions
  t.boolean :rag_enabled, default: true, null: false
  t.string :embedding_model, default: 'text-embedding-ada-002', null: false
  t.string :chat_model, default: 'gpt-4', null: false
  t.decimal :temperature, precision: 3, scale: 2, default: 0.7, null: false
  t.integer :max_tokens, default: 4096, null: false
  t.json :rag_config, default: {}
  t.json :model_config, default: {}
  t.json :tools_config, default: {}
  t.references :workspace, null: false, foreign_key: true, unique: true
  t.references :updated_by, null: false, foreign_key: { to_table: :users }
  t.timestamps
end
```

#### Routes Structure
```ruby
resources :workspaces, param: :slug do
  resources :ai_datasets do
    member do
      post :process
      post :check_status
      get 'download/:file_id', to: 'ai_datasets#download'
    end
  end
  
  resources :workspace_embedding_sources do
    member do
      post :test
      post :refresh
    end
  end
  
  resource :workspace_ai_config, path: 'ai_config' do
    member do
      post :test_rag
      post :reset_to_defaults
    end
  end
end
```

### 🔐 Security & Authorization

- **Workspace Scoping**: All resources are scoped to workspaces
- **Role-Based Access**: Admin users can modify AI configuration
- **Member Access**: All workspace members can view and manage datasets
- **File Security**: Secure file upload and download handling
- **Input Validation**: Comprehensive validation for all user inputs

### 🧪 Testing

Comprehensive test coverage including:
- **Model Tests**: Validation, business logic, and associations
- **Controller Tests**: Authorization, CRUD operations, and error handling
- **Service Tests**: OpenAI integration, file processing, and job management
- **Integration Tests**: End-to-end workflow testing

### 📱 API Support

Full REST API endpoints for:
- Dataset management (CRUD operations)
- Embedding source management
- AI configuration updates
- Fine-tuning job management

### 🎯 Key Benefits

1. **Complete User Control**: Users control all aspects of AI model, knowledge, and connectors
2. **Workspace Isolation**: Each workspace has independent AI configuration
3. **Flexible Architecture**: Support for multiple embedding source types
4. **Production Ready**: Proper error handling, logging, and monitoring
5. **Extensible**: Easy to add new source types and model providers

### 🚀 Usage Examples

#### Creating a Dataset
```ruby
dataset = workspace.ai_datasets.create!(
  name: 'Product Documentation',
  description: 'Training data for product support',
  dataset_type: 'embedding',
  created_by: current_user
)

# Upload files and process
dataset.create_embeddings!
```

#### Configuring RAG
```ruby
config = workspace.ai_config
config.update!(
  instructions: 'You are a helpful product support assistant.',
  rag_enabled: true,
  rag_config: {
    semantic_search_threshold: 0.8,
    max_context_chunks: 5
  }
)
```

#### Using RAG Context
```ruby
rag_result = config.build_rag_context('How do I reset my password?')
system_prompt = config.format_system_prompt(context: rag_result[:context])
```

This implementation provides a complete solution for workspace-scoped AI customization, enabling teams to build sophisticated AI applications with their own data and configuration.