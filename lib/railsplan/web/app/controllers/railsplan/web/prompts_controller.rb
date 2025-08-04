# frozen_string_literal: true

module Railsplan
  module Web
    class PromptsController < ApplicationController
      def index
        @prompts = load_all_prompts
        @stats = calculate_prompt_stats(@prompts)
      end
      
      def show
        @prompt = find_prompt_by_id(params[:id])
        
        if @prompt.nil?
          redirect_to railsplan_web.prompts_path, alert: "Prompt not found"
          return
        end
      end
      
      def replay
        @prompt = find_prompt_by_id(params[:id])
        
        if @prompt.nil?
          render json: { error: 'Prompt not found' }, status: :not_found
          return
        end
        
        begin
          # Replay the prompt with current context
          result = replay_prompt(@prompt)
          
          # Log the replay
          log_prompt("REPLAY: #{@prompt['prompt']}", result[:response], {
            type: 'replay',
            original_timestamp: @prompt['timestamp']
          })
          
          render json: {
            success: true,
            result: result,
            message: 'Prompt replayed successfully'
          }
        rescue => e
          Rails.logger.error "Prompt replay failed: #{e.message}" if defined?(Rails.logger)
          render json: { error: "Replay failed: #{e.message}" }, status: :internal_server_error
        end
      end
      
      private
      
      def load_all_prompts
        return [] unless File.exist?(prompt_logger)
        
        prompts = []
        File.readlines(prompt_logger).each_with_index do |line, index|
          begin
            prompt = JSON.parse(line.strip)
            prompt['id'] = index + 1
            prompts << prompt
          rescue JSON::ParserError
            next
          end
        end
        prompts.reverse
      end
      
      def find_prompt_by_id(id)
        all_prompts = load_all_prompts
        all_prompts.find { |p| p['id'] == id.to_i }
      end
      
      def calculate_prompt_stats(prompts)
        {
          total: prompts.length,
          today: prompts.count { |p| prompt_is_today?(p) },
          by_type: group_prompts_by_type(prompts),
          success_rate: calculate_success_rate(prompts)
        }
      end
      
      def prompt_is_today?(prompt)
        prompt_date = Time.parse(prompt['timestamp']).to_date
        prompt_date == Date.current
      rescue
        false
      end
      
      def group_prompts_by_type(prompts)
        type_counts = Hash.new(0)
        prompts.each do |prompt|
          type = prompt.dig('metadata', 'type') || 'unknown'
          type_counts[type] += 1
        end
        type_counts
      end
      
      def calculate_success_rate(prompts)
        return 0 if prompts.empty?
        
        successful = prompts.count do |prompt|
          response = prompt['response']
          response.is_a?(Hash) && !response.key?('error')
        end
        
        (successful.to_f / prompts.length * 100).round(1)
      end
      
      def replay_prompt(prompt)
        original_instruction = prompt['prompt']
        
        # Remove "REPLAY:" prefix if it exists
        instruction = original_instruction.gsub(/^REPLAY:\s*/, '')
        
        # Determine the type of prompt and replay accordingly
        prompt_type = prompt.dig('metadata', 'type') || 'generate'
        
        case prompt_type
        when 'generate'
          replay_generation(instruction)
        when 'upgrade'
          replay_upgrade(instruction)
        when 'doctor'
          replay_doctor
        else
          replay_chat(instruction)
        end
      end
      
      def replay_generation(instruction)
        # Use the generator to replay the instruction
        if defined?(RailsPlan::AIGenerator)
          ai_generator = RailsPlan::AIGenerator.new
          context = @app_context || {}
          result = ai_generator.generate(instruction, context)
          
          {
            type: 'generate',
            response: result,
            preview: result[:code] || result[:content] || "Replayed generation"
          }
        else
          {
            type: 'generate',
            response: { error: 'AI Generator not available' },
            preview: "AI Generator not available for replay"
          }
        end
      end
      
      def replay_upgrade(instruction)
        # Replay upgrade instruction
        {
          type: 'upgrade',
          response: { message: 'Upgrade replay not yet implemented' },
          preview: "Upgrade replay: #{instruction}"
        }
      end
      
      def replay_doctor
        # Replay doctor diagnostics
        {
          type: 'doctor',
          response: { message: 'Doctor replay not yet implemented' },
          preview: "Doctor diagnostics replayed"
        }
      end
      
      def replay_chat(instruction)
        # Replay chat instruction
        {
          type: 'chat',
          response: { message: 'Chat replay not yet implemented' },
          preview: "Chat replay: #{instruction}"
        }
      end
    end
  end
end