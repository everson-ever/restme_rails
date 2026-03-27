# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Field
        # Handles ActiveStorage attachment serialization for scoped queries.
        #
        # Responsibilities:
        #
        # - Validates requested attachment fields against the model
        # - Preloads attachment blobs to avoid N+1
        # - Injects *_url fields into the serialized JSON output
        # - Applies nested field restrictions via as_json options
        #
        # Important:
        # This class does NOT dynamically define methods on the model.
        # Attachment URLs are injected directly into the serialized hash.
        #
        # Query param:
        #
        #   ?attachment_fields_select=avatar,cover
        #
        # Response:
        #
        #   { avatar_url: "https://...", cover_url: "https://..." }
        #
        class SelectAttachments
          # @param context [RestmeRails::Context]
          # @param scope_error_instance [RestmeRails::ScopeError]
          # @param valid_nested_fields_select [Hash, nil]
          def initialize(context:, scope_error_instance:, valid_nested_fields_select:)
            @context = context
            @scope_error_instance = scope_error_instance
            @valid_nested_fields_select = valid_nested_fields_select
          end

          # Serializes the scope to JSON, injecting attachment URLs when requested.
          #
          # @param scope [ActiveRecord::Relation]
          # @return [Array<Hash>]
          def process(scope)
            return scope.as_json(json_options) if attachment_fields_select.blank?

            records = scope.includes(attachment_includes)

            serialize_with_attachments(records)
          end

          # Registers a bad_request error for attachment fields that do not
          # exist in the model's attachment_reflections.
          #
          # @return [void]
          def errors
            return if unallowed_attachment_fields.blank?

            scope_error_instance.add_error(
              body: unallowed_attachment_fields,
              message: "Selected not allowed attachment fields"
            )

            scope_error_instance.add_status(:bad_request)
          end

          private

          attr_reader :context, :scope_error_instance, :valid_nested_fields_select

          # Base as_json options including nested field restrictions.
          #
          # @return [Hash]
          def json_options
            { include: nested_include_options }
          end

          # Builds the include: hash for as_json with optional field restriction.
          #
          # Examples:
          #   { profile: nil, company: [:id, :name] }
          #   → { profile: {}, company: { only: [:id, :name] } }
          #
          # @return [Hash]
          def nested_include_options
            return {} if valid_nested_fields_select.blank?

            valid_nested_fields_select.transform_values do |fields|
              fields ? { only: fields } : {}
            end
          end

          # Serializes records and injects attachment URLs into each hash.
          #
          # Only fields present in model_attachment_fields are dispatched via
          # public_send, regardless of pipeline call order.
          #
          # @param records [ActiveRecord::Relation]
          # @return [Array<Hash>]
          def serialize_with_attachments(records)
            allowed_fields = attachment_fields_select & model_attachment_fields

            records.map do |record|
              base_hash = record.as_json(json_options)

              allowed_fields.each do |field|
                attachment = record.public_send(field)
                base_hash["#{field}_url"] = attachment&.attached? ? attachment.url : nil
              end

              base_hash
            end
          end

          # Builds the includes structure for ActiveStorage eager loading.
          #
          # Example: [:avatar] → [{ avatar_attachment: :blob }]
          #
          # @return [Array<Hash>]
          def attachment_includes
            attachment_fields_select.map do |field|
              { "#{field}_attachment": :blob }
            end
          end

          # All attachment names declared in the model via has_one_attached / has_many_attached.
          #
          # @return [Array<Symbol>]
          def model_attachment_fields
            @model_attachment_fields ||= context.model_class
                                                .attachment_reflections
                                                .map { |_name, reflection| reflection.name }
          end

          # Attachment fields requested but not present in the model.
          #
          # @return [Array<Symbol>]
          def unallowed_attachment_fields
            return [] if attachment_fields_select.blank?

            attachment_fields_select - model_attachment_fields
          end

          # Query param: attachment_fields_select
          #
          # @return [Array<Symbol>, nil]
          def attachment_fields_select
            @attachment_fields_select ||= context.query_params[:attachment_fields_select]
                                                 &.split(",")
                                                 &.map(&:to_sym)
          end
        end
      end
    end
  end
end
