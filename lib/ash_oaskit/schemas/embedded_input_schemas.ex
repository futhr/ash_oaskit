defmodule AshOaskit.SchemaBuilder.EmbeddedInputSchemas do
  @moduledoc """
  Builds action-specific embedded inputs separately from serialized output.

  Updates may create a new embed or update an existing one. Their schemas accept
  either action's input; the stored value determines which action Ash runs.
  Replacement fields and arrays without public identities use create inputs.
  """

  alias Ash.Resource.Info
  alias AshOaskit.Core.SchemaRef
  alias AshOaskit.SchemaBuilder
  alias AshOaskit.SchemaBuilder.EmbeddedSchemas
  alias AshOaskit.SchemaBuilder.ResourceSchemas
  alias AshOaskit.TypeMapper

  @doc false
  @spec add_field(map(), map(), keyword()) :: map()
  def add_field(builder, field, opts) do
    field
    |> TypeMapper.embedded_fields()
    |> Enum.reduce(builder, &add_embedded(&2, &1, opts))
  end

  defp add_embedded(builder, field, opts) do
    opts = Keyword.put(opts, :array?, Map.get(field, :array?, false))
    builder = EmbeddedSchemas.reserve_name(builder, field.type)

    field.type
    |> actions(field.constraints, opts)
    |> Enum.reduce(builder, &add_action(&2, field, &1))
  end

  @doc false
  @spec reference(module(), keyword(), keyword()) :: map()
  def reference(resource, constraints, opts) do
    refs =
      resource
      |> actions(constraints, opts)
      |> Enum.map(&SchemaRef.schema_ref(schema_name(resource, constraints, &1)))

    case refs do
      [ref] -> ref
      refs -> %{"anyOf" => refs}
    end
  end

  defp actions(resource, constraints, opts) do
    create = action(resource, constraints, :create)

    if Keyword.get(opts, :action_type) == :update and updatable?(resource, constraints, opts),
      do: Enum.uniq([create, action(resource, constraints, :update)]),
      else: [create]
  end

  defp action(resource, constraints, type) do
    key = if type == :create, do: :create_action, else: :update_action
    Keyword.get(constraints, key) || Info.primary_action!(resource, type).name
  end

  defp updatable?(resource, constraints, opts) do
    constraints[:on_update] != :replace and
      (not Keyword.get(opts, :array?, false) or
         Enum.any?(Info.public_attributes(resource), & &1.primary_key?))
  end

  defp schema_name(resource, constraints, action) do
    ResourceSchemas.action_input_schema_name(schema_prefix(resource, constraints), action)
  end

  defp schema_prefix(resource, constraints) do
    name = resource |> Module.split() |> List.last()

    case skipped_inputs(constraints) do
      [] ->
        name

      skipped ->
        name <>
          "_" <> Base.encode16(:crypto.hash(:sha256, Enum.join(skipped, "\0")), case: :lower)
    end
  end

  defp skipped_inputs(constraints) do
    constraints
    |> Keyword.get(:skip_unknown_inputs, [])
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.sort()
  end

  defp add_action(builder, field, action) do
    name = schema_name(field.type, field.constraints, action)
    key = {field.type, name}
    seen = builder.seen_input_types

    if MapSet.member?(seen, key) do
      builder
    else
      builder
      |> Map.put(:seen_input_types, MapSet.put(seen, key))
      |> ResourceSchemas.add_action_input_schema(
        field.type,
        action,
        schema_prefix(field.type, field.constraints),
        add_schema_fn: &SchemaBuilder.add_schema/3
      )
      |> allow_skipped_inputs(name, field)
    end
  end

  defp allow_skipped_inputs(builder, name, field) do
    skipped = skipped_inputs(field.constraints)

    public_ids =
      field.type
      |> Info.public_attributes()
      |> Enum.filter(& &1.primary_key?)
      |> Enum.map(&to_string(&1.name))

    ignored = Map.new(Enum.reject(skipped, &(&1 == "*")) ++ public_ids, &{&1, %{}})

    update_in(builder, [:schemas, name], fn schema ->
      schema
      |> Map.put(:additionalProperties, "*" in skipped)
      |> Map.update!(:properties, &merge_ignored(&1, ignored))
    end)
  end

  defp merge_ignored(properties, ignored) do
    known = Enum.map(Map.keys(properties), &to_string/1)
    Map.merge(Map.drop(ignored, known), properties)
  end
end
