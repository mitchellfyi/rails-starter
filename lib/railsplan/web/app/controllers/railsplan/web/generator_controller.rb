# frozen_string_literal: true

module Railsplan
  module Web
    class GeneratorController < ApplicationController
      def index
        @recent_generations = load_recent_generations
      end
      
      def create
        @instruction = params[:instruction].to_s.strip
        
        if @instruction.blank?
          render json: { error: 'Instruction cannot be blank' }, status: :bad_request
          return
        end
        
        # Generate code using AI
        begin
          result = generate_code_with_ai(@instruction)
          
          # Log the prompt and response
          log_prompt(@instruction, result[:response], { 
            type: 'generate',
            files_generated: result[:files]&.keys || []
          })
          
          render json: {
            success: true,
            preview: result[:preview],
            files: result[:files],
            explanation: result[:explanation]
          }
        rescue => e
          Rails.logger.error "AI generation failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Generation failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      def preview
        @instruction = params[:instruction].to_s.strip
        
        if @instruction.blank?
          render json: { error: 'Instruction cannot be blank' }, status: :bad_request
          return
        end
        
        begin
          result = preview_code_generation(@instruction)
          
          render json: {
            success: true,
            preview: result[:preview],
            estimated_files: result[:estimated_files],
            explanation: result[:explanation]
          }
        rescue => e
          Rails.logger.error "AI preview failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Preview failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      def apply
        files_data = params[:files]
        
        if files_data.blank?
          render json: { error: 'No files to apply' }, status: :bad_request
          return
        end
        
        begin
          applied_files = apply_generated_files(files_data)
          
          render json: {
            success: true,
            applied_files: applied_files,
            message: "Successfully applied #{applied_files.length} files"
          }
        rescue => e
          Rails.logger.error "File application failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Application failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      private
      
      def load_recent_generations
        return [] unless File.exist?(prompt_logger)
        
        generations = []
        File.readlines(prompt_logger).last(20).each do |line|
          entry = JSON.parse(line.strip)
          if entry['metadata'] && entry['metadata']['type'] == 'generate'
            generations << entry
          end
        rescue JSON::ParserError
          next
        end
        generations.reverse.first(10)
      end
      
      def generate_code_with_ai(instruction)
        # Use existing AI infrastructure
        ai_generator = RailsPlan::AIGenerator.new if defined?(RailsPlan::AIGenerator)
        
        unless ai_generator
          return {
            preview: "AI Generator not available. Please ensure RailsPlan is properly configured.",
            files: {},
            explanation: "AI generation requires proper configuration."
          }
        end
        
        # Generate code using the existing system
        context = @app_context || {}
        result = ai_generator.generate(instruction, context)
        
        {
          preview: result[:code] || result[:content] || "Generated code",
          files: result[:files] || {},
          explanation: result[:explanation] || "Code generated successfully",
          response: result
        }
      rescue => e
        {
          preview: "Error generating code: #{e.message}",
          files: {},
          explanation: "Generation failed due to an error.",
          response: { error: e.message }
        }
      end
      
      def preview_code_generation(instruction)
        # Create a preview without actually generating files
        estimated_files = estimate_files_from_instruction(instruction)
        
        {
          preview: "This will generate code based on: #{instruction}",
          estimated_files: estimated_files,
          explanation: "Preview of what would be generated"
        }
      end
      
      def estimate_files_from_instruction(instruction)
        files = []
        
        # Simple heuristics to estimate what files might be generated
        if instruction.downcase.include?('model')
          files << 'app/models/[name].rb'
          files << 'db/migrate/[timestamp]_create_[name].rb'
        end
        
        if instruction.downcase.include?('controller')
          files << 'app/controllers/[name]_controller.rb'
          files << 'app/views/[name]/index.html.erb'
        end
        
        if instruction.downcase.include?('test')
          files << 'test/models/[name]_test.rb'
          files << 'test/controllers/[name]_controller_test.rb'
        end
        
        files.empty? ? ['Generated files will appear here'] : files
      end
      
      def apply_generated_files(files_data)
        applied_files = []
        
        # Create .railsplan/ui directory for temporary files
        ui_dir = Rails.root.join('.railsplan', 'ui')
        FileUtils.mkdir_p(ui_dir)
        
        files_data.each do |file_path, content|
          # For now, save to temp directory instead of directly applying
          temp_file = ui_dir.join("#{File.basename(file_path)}.tmp")
          File.write(temp_file, content)
          applied_files << temp_file.to_s
        end
        
        applied_files
      end
    end
  end
end