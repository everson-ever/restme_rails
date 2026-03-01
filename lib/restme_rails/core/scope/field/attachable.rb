# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Field
        # Handles attachment field selection for scoped queries.
        #
        # Responsibilities:
        #
        # - Validates selected attachment fields
        # - Prevents unallowed attachment access
        # - Serializes attachment URLs without mutating the model class
        #
        # Important:
        # This version does NOT dynamically define methods on the model.
        # Attachment URLs are injected directly into the serialized JSON.
        #
        # Expected behavior:
        #
        # If the request includes:
        #   attachment_fields_select: [:avatar]
        #
        # The JSON response will include:
        #   {
        #     avatar_url: "https://..."
        #   }
        #
        class Attachable
          attr_reader :context,
                      :attachment_fields_select,
                      :valid_nested_fields_select,
                      :scope_error_instance

          def initialize(context:, attachment_fields_select:, valid_nested_fields_select:, scope_error_instance:)
            @context = context
            @attachment_fields_select = attachment_fields_select
            @valid_nested_fields_select = valid_nested_fields_select
            @scope_error_instance = scope_error_instance
          end

          # Applies attachment logic to a given ActiveRecord scope.
          #
          # Steps:
          # 1. Validates unallowed attachment fields
          # 2. If none selected, returns normal JSON
          # 3. Preloads attachments
          # 4. Injects *_url fields directly into serialized hash
          #
          # @param scope [ActiveRecord::Relation]
          # @return [Array<Hash>]
          def insert_attachments(scope)
            unallowed_attachment_fields_errors

            return scope.as_json(json_options) if attachment_fields_select.blank?

            records = scope.includes(attachment_includes)

            serialize_with_attachments(records)
          end

          # Registers bad_request error if client selected
          # attachment fields that do not exist in the model.
          #
          # @return [void]
          def unallowed_attachment_fields_errors
            return if unallowed_attachment_fields.blank?

            scope_error_instance.add_error(
              body: unallowed_attachment_fields,
              message: "Selected not allowed attachment fields"
            )

            scope_error_instance.add_status(:bad_request)
          end

          private

          # Base JSON options (without attachment methods).
          #
          # @return [Hash]
          def json_options
            {
              include: valid_nested_fields_select
            }
          end

          # Serializes records and injects attachment URLs.
          #
          # @param records [ActiveRecord::Relation]
          # @return [Array<Hash>]
          def serialize_with_attachments(records)
            records.map do |record|
              base_hash = record.as_json(json_options)

              attachment_fields_select.each do |field|
                attachment = record.public_send(field)

                base_hash["#{field}_url"] =
                  attachment&.attached? ? attachment.url : nil
              end

              base_hash
            end
          end

          # Builds includes structure for ActiveStorage eager loading.
          #
          # Example:
          #   { avatar_attachment: :blob }
          #
          # @return [Array<Hash>]
          def attachment_includes
            attachment_fields_select.map do |field|
              { "#{field}_attachment": :blob }
            end
          end

          # Returns all attachment names declared in the model.
          #
          # @return [Array<Symbol>]
          def model_attachment_fields
            @model_attachment_fields ||= context.model_class
                                                .attachment_reflections
                                                .map { |_name, reflection| reflection.name }
          end

          # Returns fields requested but not present in the model.
          #
          # @return [Array<Symbol>]
          def unallowed_attachment_fields
            return [] if attachment_fields_select.blank?

            attachment_fields_select - model_attachment_fields
          end
        end
      end
    end
  end
end
