# frozen_string_literal: true

module RestmeRails
  # Responsible for resolving the Rules class associated with a given model
  # and rule context.
  #
  # This class dynamically builds the expected constant name for a rules
  # namespace and attempts to resolve it using `safe_constantize`.
  #
  # The expected convention is:
  #
  #   <ModelName>Rules::<RuleContext>::Rules
  #
  # Example:
  #
  #   klass: Product
  #   rule_context: :Scope
  #
  # Will attempt to resolve:
  #
  #   "ProductRules::Scope::Rules"
  #
  # If the constant exists, it is returned.
  # If it does not exist, nil is returned.
  #
  # @example Basic usage
  #   finder = RestmeRails::RulesFind.new(
  #     klass: Product,
  #     rule_context: :Scope
  #   )
  #
  #   finder.rule_class
  #   # => ProductRules::Scope::Rules (if defined)
  #
  # @note This class relies on Rails' `safe_constantize`.
  # @note Returns nil if the rule class is not defined.
  class RulesFind
    # @param klass [Class]
    #   The base model class used to build the rules namespace.
    #
    # @param rule_context [String, Symbol]
    #   The rule context (e.g., :Scope, :Create, :Update, :Authorize).
    #
    # @raise [ArgumentError]
    #   If klass is nil.
    def initialize(klass:, rule_context:)
      @klass = klass
      @rule_context = rule_context
    end

    # Resolves the rules class for the given model and context.
    #
    # Convention:
    #   "#{klass.name}Rules::#{rule_context}::Rules"
    #
    # @return [Class, nil]
    #   The resolved rules class if defined, otherwise nil.
    def rule_class
      context = @rule_context.to_s.camelize
      "#{@klass.name}Rules::#{context}::Rules".safe_constantize
    end
  end
end
