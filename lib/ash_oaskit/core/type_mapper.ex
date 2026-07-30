defmodule AshOaskit.TypeMapper do
  @moduledoc """
  Maps Ash types to JSON Schema types for OpenAPI 3.0 and 3.1.

  This module handles the conversion of Ash resource attributes to their
  corresponding JSON Schema representations, respecting the differences
  between OpenAPI versions.

  ## Version Differences

  - **OpenAPI 3.0**: Uses `nullable: true` for nullable fields. `$ref`
    schemas are wrapped in `allOf` first, because 3.0 ignores sibling
    keys next to `$ref`.
  - **OpenAPI 3.1**: Uses type arrays like `["string", "null"]`; `$ref`
    schemas are wrapped in `oneOf` with a null type.

  ## Supported Types

  | Ash Type | JSON Schema Type | Format |
  |----------|------------------|--------|
  | `:string` | `string` | - |
  | `:ci_string` | `string` | - |
  | `:integer` | `integer` | - |
  | `:float` | `number` | `float` |
  | `:decimal` | `number` | `double` |
  | `:boolean` | `boolean` | - |
  | `:date` | `string` | `date` |
  | `:time` | `string` | `time` |
  | `:time_usec` | `string` | `time` |
  | `:datetime` | `string` | `date-time` |
  | `:utc_datetime` | `string` | `date-time` |
  | `:utc_datetime_usec` | `string` | `date-time` |
  | `:naive_datetime` | `string` | `date-time` |
  | `:duration` | `string` | `duration` |
  | `:uuid` | `string` | `uuid` |
  | `:uuid_v7` | `string` | `uuid` |
  | `:binary` | `string` | `binary` |
  | `:url_encoded_binary` | `string` | `byte` |
  | `:map` | `object` | - |
  | `:keyword` | `object` | - |
  | `:tuple` | `object` | - |
  | `:atom` | `string` | - |
  | `:module` | `string` | - |
  | `:term` | (empty schema) | - |
  | `:function` | (empty schema) | - |
  | `:vector` | `array` of `number` | - |
  | `{:array, type}` | `array` | items: nested type |

  ## Advanced Types

  | Ash Type | JSON Schema | Notes |
  |----------|-------------|-------|
  | `Ash.Type.Union` | `anyOf` | With optional discriminator |
  | `Ash.Type.Struct` | `object` | With constrained properties |
  | `Ash.Type.File` | `string` (`byte`) | Base64 encoded content |
  | `Ash.Type.DurationName` | `string` | Enum from the type's `values/0` |
  | `Ash.Type.Enum` implementors | `string` | Enum from the type's `values/0` |
  | `Ash.TypedStruct` modules | `object` | Typed properties and required list from the field definitions |
  | `Ash.Type.NewType` wrappers | (subtype schema) | Resolved via `subtype_of/0` |
  | Custom types | Calls `json_schema/1` | If defined on type |

  ## Supported Constraints

  | Ash Constraint | JSON Schema Property |
  |----------------|---------------------|
  | `:min_length` | `minLength` |
  | `:max_length` | `maxLength` |
  | `:min` | `minimum` |
  | `:max` | `maximum` |
  | `:match` (Regex) | `pattern` |
  | `:one_of` | `enum` |
  | array `:min_length` | `minItems` |
  | array `:max_length` | `maxItems` |
  | array `:items` | Constraints applied to `items` |
  | array `:nil_items?` | Nullable `items` schema |
  | UUIDv7 `:strict?` | Version 7 UUID pattern |

  ## Additional Schema Properties

  - `description` - Copied from attribute description
  - `default` - Copied from attribute default (non-function values only)
  """

  # Suppress dialyzer warning for make_nullable_31/1 - the is_list guard is valid
  # at runtime even though dialyzer thinks the type is narrowed to binary/map.
  # OpenAPI 3.1 schemas can have "type" as either a string or list of strings.
  @dialyzer {:nowarn_function, make_nullable_31: 1}

  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1]

  alias Ash.Type.NewType

  require Logger

  @uuid_v7_pattern "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-7[0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"

  @doc """
  Convert an Ash attribute to a JSON Schema for OpenAPI 3.1.

  In OpenAPI 3.1, nullable is represented as a type array:
  `{"type": ["string", "null"]}` instead of `{"type": "string", "nullable": true}`

  ## Examples

      iex> attr = %{type: :string, allow_nil?: false}
      ...> AshOaskit.TypeMapper.to_json_schema_31(attr)
      %{"type" => "string"}

      iex> attr = %{type: :string, allow_nil?: true}
      ...> AshOaskit.TypeMapper.to_json_schema_31(attr)
      %{"type" => ["string", "null"]}

      iex> attr = %{type: :uuid, allow_nil?: false}
      ...> AshOaskit.TypeMapper.to_json_schema_31(attr)
      %{"type" => "string", "format" => "uuid"}

  """
  @spec to_json_schema_31(map()) :: map()
  def to_json_schema_31(attr) do
    base_schema = ash_type_to_base_schema(resolve_type(attr), constraints(attr), "3.1")

    schema =
      if allow_nil?(attr) do
        make_nullable_31(base_schema)
      else
        base_schema
      end

    schema
    |> maybe_add_description(attr)
    |> maybe_add_default(attr)
  end

  @doc """
  Convert an Ash attribute to a JSON Schema for OpenAPI 3.0.

  In OpenAPI 3.0, nullable is represented with a boolean flag:
  `{"type": "string", "nullable": true}`

  ## Examples

      iex> attr = %{type: :string, allow_nil?: false}
      ...> AshOaskit.TypeMapper.to_json_schema_30(attr)
      %{"type" => "string"}

      iex> attr = %{type: :string, allow_nil?: true}
      ...> AshOaskit.TypeMapper.to_json_schema_30(attr)
      %{"type" => "string", "nullable" => true}

  """
  @spec to_json_schema_30(map()) :: map()
  def to_json_schema_30(attr) do
    base_schema = ash_type_to_base_schema(resolve_type(attr), constraints(attr), "3.0")

    schema =
      if allow_nil?(attr) do
        make_nullable_30(base_schema)
      else
        base_schema
      end

    schema
    |> maybe_add_description(attr)
    |> maybe_add_default(attr)
  end

  # For Ash.Type.NewType subtypes of Ash.Type.Union, the actual union variant
  # types are in the attribute's constraints[:types], not discoverable from
  # the type module's constraints/0 (which returns constraint definitions).
  defp resolve_type(%{type: type, constraints: constraints})
       when is_atom(type) and is_list(constraints) do
    with true <- union_newtype?(type),
         types when is_list(types) and types != [] <- Keyword.get(constraints, :types) do
      {:union, types}
    else
      _ -> type
    end
  end

  defp resolve_type(%{type: type}), do: type

  defp constraints(%{constraints: constraints}) when is_list(constraints), do: constraints
  defp constraints(_), do: []

  defp union_newtype?(type) do
    Code.ensure_loaded?(type) and
      function_exported?(type, :subtype_of, 0) and
      type.subtype_of() == Ash.Type.Union
  end

  @simple_type_schemas %{
    string: %{"type" => "string"},
    ci_string: %{"type" => "string"},
    integer: %{"type" => "integer"},
    float: %{"type" => "number", "format" => "float"},
    decimal: %{"type" => "number", "format" => "double"},
    boolean: %{"type" => "boolean"},
    date: %{"type" => "string", "format" => "date"},
    time: %{"type" => "string", "format" => "time"},
    time_usec: %{"type" => "string", "format" => "time"},
    datetime: %{"type" => "string", "format" => "date-time"},
    utc_datetime: %{"type" => "string", "format" => "date-time"},
    utc_datetime_usec: %{"type" => "string", "format" => "date-time"},
    naive_datetime: %{"type" => "string", "format" => "date-time"},
    duration: %{"type" => "string", "format" => "duration"},
    uuid: %{"type" => "string", "format" => "uuid"},
    uuid_v7: %{"type" => "string", "format" => "uuid"},
    binary: %{"type" => "string", "format" => "binary"},
    url_encoded_binary: %{"type" => "string", "format" => "byte"},
    map: %{"type" => "object"},
    keyword: %{"type" => "object"},
    tuple: %{"type" => "object"},
    atom: %{"type" => "string"},
    module: %{"type" => "string"},
    term: %{},
    function: %{},
    vector: %{"type" => "array", "items" => %{"type" => "number"}},
    file: %{
      "type" => "string",
      "format" => "byte",
      "description" => "Base64 encoded file content"
    },
    duration_name: %{
      "type" => "string",
      "enum" => Enum.map(Ash.Type.DurationName.values(), &to_string/1),
      "description" => "Duration unit name"
    }
  }

  defp ash_type_to_base_schema(type, constraints, version) do
    normalized = normalize_type(type, constraints)

    normalized
    |> schema_for_normalized_type(version)
    |> apply_constraints(constraint_type(type), effective_constraints(type, constraints), version)
  end

  defp schema_for_normalized_type(type, version) do
    simple_type_schema(type) || complex_type_schema(type, version)
  end

  defp simple_type_schema(type) when is_atom(type), do: Map.get(@simple_type_schemas, type)
  defp simple_type_schema(_), do: nil

  defp complex_type_schema({:array, inner_type}, version) do
    %{"type" => "array", "items" => schema_for_normalized_type(inner_type, version)}
  end

  defp complex_type_schema({:embedded, module}, _) do
    schema_name = module |> Module.split() |> List.last()
    schema_ref(schema_name)
  end

  defp complex_type_schema({:union, types}, version), do: build_union_schema(types, version)
  defp complex_type_schema({:struct, module}, _), do: build_struct_schema(module)

  defp complex_type_schema({:struct_fields, module}, version),
    do: build_typed_struct_schema(module, version)

  defp complex_type_schema({:custom, custom_schema}, _), do: custom_schema
  defp complex_type_schema(_, _), do: %{"type" => "string"}

  defp build_union_schema(types, version) when is_list(types) do
    any_of =
      Enum.map(types, fn
        {name, type_config} when is_list(type_config) ->
          inner_type = Keyword.get(type_config, :type, :string)
          constraints = Keyword.get(type_config, :constraints, [])
          schema = ash_type_to_base_schema(inner_type, constraints, version)
          Map.put(schema, "title", to_string(name))

        type when is_atom(type) ->
          ash_type_to_base_schema(type, [], version)

        _ ->
          %{"type" => "string"}
      end)

    %{"anyOf" => any_of}
  end

  defp build_union_schema(_, _), do: %{}

  defp build_struct_schema(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0) do
      fields = module.__struct__() |> Map.keys() |> Enum.reject(&(&1 == :__struct__))

      properties =
        Map.new(fields, fn field -> {to_string(field), %{"type" => "string"}} end)

      %{
        "type" => "object",
        "properties" => properties,
        "description" => "Struct of type #{inspect(module)}"
      }
    else
      %{"type" => "object"}
    end
  end

  defp build_struct_schema(_), do: %{"type" => "object"}

  # Build an object schema for a NewType of Ash.Type.Struct (e.g. a
  # module defined with `use Ash.TypedStruct`). Unlike build_struct_schema/1,
  # the field definitions carry declared types and allow_nil? flags in the
  # NewType's subtype constraints, so properties keep their real types and
  # non-nil fields become required.
  defp build_typed_struct_schema(module, version) do
    fields = module.subtype_constraints()[:fields] || []

    properties =
      Map.new(fields, fn {name, config} ->
        type = Keyword.get(config, :type, :string)
        constraints = Keyword.get(config, :constraints, [])
        schema = ash_type_to_base_schema(type, constraints, version)

        schema =
          if Keyword.get(config, :allow_nil?, true) do
            make_nullable(schema, version)
          else
            schema
          end

        {to_string(name), schema}
      end)

    required =
      for {name, config} <- fields,
          Keyword.get(config, :allow_nil?, true) == false,
          do: to_string(name)

    schema = %{
      "type" => "object",
      "properties" => properties,
      "description" => "Struct of type #{inspect(module)}"
    }

    if required == [] do
      schema
    else
      Map.put(schema, "required", Enum.sort(required))
    end
  end

  @basic_types ~w(string ci_string integer float decimal boolean date time time_usec
                  datetime utc_datetime utc_datetime_usec naive_datetime duration uuid
                  uuid_v7 binary url_encoded_binary map keyword tuple atom module term
                  function vector file duration_name)a

  @ash_type_to_atom %{
    Ash.Type.String => :string,
    Ash.Type.CiString => :ci_string,
    Ash.Type.Integer => :integer,
    Ash.Type.Float => :float,
    Ash.Type.Decimal => :decimal,
    Ash.Type.Boolean => :boolean,
    Ash.Type.Date => :date,
    Ash.Type.Time => :time,
    Ash.Type.TimeUsec => :time_usec,
    Ash.Type.DateTime => :datetime,
    Ash.Type.UtcDatetime => :utc_datetime,
    Ash.Type.UtcDatetimeUsec => :utc_datetime_usec,
    Ash.Type.NaiveDatetime => :naive_datetime,
    Ash.Type.Duration => :duration,
    Ash.Type.UUID => :uuid,
    Ash.Type.UUIDv7 => :uuid_v7,
    Ash.Type.Binary => :binary,
    Ash.Type.UrlEncodedBinary => :url_encoded_binary,
    Ash.Type.Map => :map,
    Ash.Type.Keyword => :keyword,
    Ash.Type.Tuple => :tuple,
    Ash.Type.Atom => :atom,
    Ash.Type.Module => :module,
    Ash.Type.Term => :term,
    Ash.Type.Function => :function,
    Ash.Type.Vector => :vector,
    Ash.Type.File => :file,
    Ash.Type.DurationName => :duration_name
  }

  defp normalize_type(type, constraints)

  defp normalize_type({:union, types}, _), do: {:union, types}
  defp normalize_type({:struct, module}, _), do: {:struct, module}
  defp normalize_type({:embedded, module}, _), do: {:embedded, module}

  defp normalize_type({:array, inner}, constraints) do
    {:array, normalize_type(inner, Keyword.get(constraints, :items, []))}
  end

  # Handle tuple types (legacy format) - first element is the type module
  defp normalize_type(type, _) when is_tuple(type) do
    Map.get(@ash_type_to_atom, elem(type, 0), :string)
  end

  defp normalize_type(type, constraints) when is_atom(type) do
    cond do
      type in @basic_types -> type
      Map.has_key?(@ash_type_to_atom, type) -> Map.get(@ash_type_to_atom, type)
      true -> normalize_complex_type(type, constraints)
    end
  end

  defp normalize_type(_, _), do: :string

  # Handle complex type checking for embedded resources, custom types, unions,
  # Ash.Type.Enum implementors, and NewType wrappers
  defp normalize_complex_type(type, constraints) do
    cond do
      # Custom types own their schema even when they also wrap a built-in type.
      has_json_schema_callback?(type) ->
        {:custom, get_custom_json_schema(type, constraints)}

      embedded_resource?(type) ->
        {:embedded, type}

      union_result = get_union_types(type) ->
        union_result

      enum_type?(type) ->
        {:custom, enum_schema(type)}

      newtype?(type) ->
        normalize_newtype(type, constraints)

      true ->
        :string
    end
  end

  # NewType wrappers resolve to their subtype — except typed structs
  # (subtype_of: :struct, e.g. `use Ash.TypedStruct`), whose field
  # definitions live in the NewType's constraints and would be lost by
  # plain recursion on the subtype
  defp normalize_newtype(type, constraints) do
    case NewType.subtype_of(type) do
      Ash.Type.Struct -> {:struct_fields, type}
      subtype -> normalize_type(subtype, effective_constraints(type, constraints))
    end
  end

  defp enum_type?(type) do
    Code.ensure_loaded?(type) and Spark.implements_behaviour?(type, Ash.Type.Enum)
  end

  defp enum_schema(type) do
    %{"type" => "string", "enum" => Enum.map(type.values(), &to_string/1)}
  end

  # Check if a type is an Ash.Type.NewType wrapper (union NewTypes are
  # already resolved earlier via the attribute constraints)
  defp newtype?(type) do
    Code.ensure_loaded?(type) and NewType.new_type?(type)
  end

  defp has_json_schema_callback?(type) do
    Code.ensure_loaded?(type) and function_exported?(type, :json_schema, 1)
  end

  defp get_custom_json_schema(type, constraints) do
    type.json_schema(constraints)
  rescue
    e ->
      Logger.warning(fn ->
        "Failed to get json_schema for #{inspect(type)}: #{Exception.message(e)}"
      end)

      %{"type" => "string"}
  end

  # Check if a type is a union type and return {:union, types} or false
  # Only called from normalize_complex_type which guarantees type is an atom
  defp get_union_types(type) do
    with true <- Code.ensure_loaded?(type),
         true <- function_exported?(type, :constraints, 0),
         types when is_list(types) <- Keyword.get(type.constraints(), :types) do
      {:union, types}
    else
      _ -> false
    end
  end

  @spec embedded_resource?(atom()) :: boolean()
  defp embedded_resource?(type) when is_atom(type) do
    Code.ensure_loaded?(type) and
      function_exported?(type, :spark_is, 0) and
      Spark.Dsl.is?(type, Ash.Resource) and
      ash_embedded?(type)
  end

  @spec ash_embedded?(atom()) :: boolean()
  defp ash_embedded?(resource), do: Ash.Resource.Info.embedded?(resource)

  defp allow_nil?(%{allow_nil?: allow_nil?}), do: allow_nil?
  defp allow_nil?(_), do: true

  # Make nullable for OpenAPI 3.1 (type array)
  # Base schemas always have single type strings, so we convert to array with null
  defp make_nullable_31(%{"type" => type} = schema) when is_binary(type) do
    Map.put(schema, "type", [type, "null"])
  end

  # For $ref schemas, wrap in oneOf with null type
  defp make_nullable_31(%{"$ref" => _} = schema) do
    %{"oneOf" => [%{"type" => "null"}, schema]}
  end

  # For anyOf schemas, prepend null type to existing list
  defp make_nullable_31(%{"anyOf" => schemas}) do
    %{"anyOf" => [%{"type" => "null"} | schemas]}
  end

  # Empty schema (e.g. :term) already accepts any value including null
  defp make_nullable_31(schema), do: schema

  # Make nullable for OpenAPI 3.0 (nullable flag)
  # Sibling keys next to $ref are ignored in 3.0, so the ref must be
  # wrapped in allOf for nullable to take effect
  defp make_nullable_30(%{"$ref" => _} = schema) do
    %{"allOf" => [schema], "nullable" => true}
  end

  defp make_nullable_30(schema) do
    Map.put(schema, "nullable", true)
  end

  defp apply_constraints(schema, {:array, inner_type}, constraints, version) do
    schema
    |> apply_item_constraints(inner_type, constraints, version)
    |> apply_constraint_keywords(constraints, :array)
  end

  defp apply_constraints(schema, type, constraints, _) do
    apply_constraint_keywords(schema, constraints, type)
  end

  defp apply_item_constraints(schema, inner_type, constraints, version) do
    item_constraints = Keyword.get(constraints, :items, [])

    Map.update(schema, "items", %{}, fn items ->
      items =
        if is_list(item_constraints) do
          apply_constraints(items, constraint_type(inner_type), item_constraints, version)
        else
          items
        end

      if Keyword.get(constraints, :nil_items?, false) do
        make_nullable(items, version)
      else
        items
      end
    end)
  end

  defp make_nullable(schema, "3.1"), do: make_nullable_31(schema)
  defp make_nullable(schema, _), do: make_nullable_30(schema)

  defp constraint_type({:array, inner_type}), do: {:array, inner_type}
  defp constraint_type(type) when type in [:uuid_v7, Ash.Type.UUIDv7], do: :uuid_v7

  defp constraint_type(type) when is_atom(type) do
    if newtype?(type), do: constraint_type(NewType.subtype_of(type)), else: :scalar
  end

  defp constraint_type(_), do: :scalar

  defp effective_constraints(type, constraints) when is_atom(type) do
    if newtype?(type) and not has_json_schema_callback?(type) do
      constraints = NewType.constraints(type, constraints)
      type.type_constraints(constraints, type.subtype_constraints())
    else
      constraints
    end
  end

  defp effective_constraints(_, constraints), do: constraints

  defp apply_constraint_keywords(schema, constraints, type) do
    Enum.reduce(constraints, schema, fn
      {:min_length, min}, acc ->
        Map.put(acc, length_constraint(type, "min"), min)

      {:max_length, max}, acc ->
        Map.put(acc, length_constraint(type, "max"), max)

      {:min, min}, acc ->
        Map.put(acc, "minimum", to_number(min))

      {:max, max}, acc ->
        Map.put(acc, "maximum", to_number(max))

      {:match, pattern}, acc when is_struct(pattern, Regex) ->
        Map.put(acc, "pattern", Regex.source(pattern))

      {:match, {Spark.Regex, :cache, [pattern_string, _]}}, acc
      when is_binary(pattern_string) ->
        Map.put(acc, "pattern", pattern_string)

      {:one_of, values}, acc ->
        Map.put(acc, "enum", Enum.map(values, &sanitize_default/1))

      {:strict?, true}, acc when type == :uuid_v7 ->
        Map.put(acc, "pattern", @uuid_v7_pattern)

      _, acc ->
        acc
    end)
  end

  defp length_constraint(:array, "min"), do: "minItems"
  defp length_constraint(:array, "max"), do: "maxItems"
  defp length_constraint(_, "min"), do: "minLength"
  defp length_constraint(_, "max"), do: "maxLength"

  defp maybe_add_description(schema, %{description: desc}) when is_binary(desc) do
    Map.put(schema, "description", desc)
  end

  defp maybe_add_description(schema, _), do: schema

  # Add default value (skip nil and function defaults - they can't be represented in OpenAPI)
  defp maybe_add_default(schema, %{default: default})
       when default != nil and not is_function(default) do
    Map.put(schema, "default", sanitize_default(default))
  end

  defp maybe_add_default(schema, _), do: schema

  defp sanitize_default(%Decimal{} = d), do: Decimal.to_float(d)

  defp sanitize_default(value) when is_atom(value) and value not in [true, false],
    do: to_string(value)

  defp sanitize_default(value), do: value

  defp to_number(value) when is_number(value), do: value
  defp to_number(%Decimal{} = value), do: Decimal.to_float(value)

  defp to_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> value
        end
    end
  end

  defp to_number(value), do: value
end
