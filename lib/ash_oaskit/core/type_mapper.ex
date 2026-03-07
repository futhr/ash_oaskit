defmodule AshOaskit.TypeMapper do
  @moduledoc """
  Maps Ash types to JSON Schema types for OpenAPI 3.0 and 3.1.

  This module handles the conversion of Ash resource attributes to their
  corresponding JSON Schema representations, respecting the differences
  between OpenAPI versions.

  ## Version Differences

  - **OpenAPI 3.0**: Uses `nullable: true` for nullable fields
  - **OpenAPI 3.1**: Uses type arrays like `["string", "null"]`

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
  | `:datetime` | `string` | `date-time` |
  | `:utc_datetime` | `string` | `date-time` |
  | `:utc_datetime_usec` | `string` | `date-time` |
  | `:naive_datetime` | `string` | `date-time` |
  | `:uuid` | `string` | `uuid` |
  | `:binary` | `string` | `binary` |
  | `:map` | `object` | - |
  | `:atom` | `string` | - |
  | `:term` | (empty schema) | - |
  | `{:array, type}` | `array` | items: nested type |

  ## Advanced Types

  | Ash Type | JSON Schema | Notes |
  |----------|-------------|-------|
  | `Ash.Type.Union` | `anyOf` | With optional discriminator |
  | `Ash.Type.Struct` | `object` | With constrained properties |
  | `Ash.Type.File` | `string`/`object` | Binary or file object |
  | `Ash.Type.DurationName` | `string` | With duration enum |
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

  ## Additional Schema Properties

  - `description` - Copied from attribute description
  - `default` - Copied from attribute default (non-function values only)
  """

  # Suppress dialyzer warning for make_nullable_31/1 - the is_list guard is valid
  # at runtime even though dialyzer thinks the type is narrowed to binary/map.
  # OpenAPI 3.1 schemas can have "type" as either a string or list of strings.
  @dialyzer {:nowarn_function, make_nullable_31: 1}

  require Logger

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
    base_schema = ash_type_to_base_schema(resolve_type(attr))

    schema =
      if allow_nil?(attr) do
        make_nullable_31(base_schema)
      else
        base_schema
      end

    schema
    |> maybe_add_constraints(attr)
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
    base_schema = ash_type_to_base_schema(resolve_type(attr))

    schema =
      if allow_nil?(attr) do
        make_nullable_30(base_schema)
      else
        base_schema
      end

    schema
    |> maybe_add_constraints(attr)
    |> maybe_add_description(attr)
    |> maybe_add_default(attr)
  end

  # Resolve the effective type for an attribute.
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

  # Check if a type module is a NewType subtype of Ash.Type.Union
  defp union_newtype?(type) do
    Code.ensure_loaded?(type) and
      function_exported?(type, :subtype_of, 0) and
      type.subtype_of() == Ash.Type.Union
  end

  # Map of simple types to their JSON Schema representation
  @simple_type_schemas %{
    string: %{"type" => "string"},
    ci_string: %{"type" => "string"},
    integer: %{"type" => "integer"},
    float: %{"type" => "number", "format" => "float"},
    decimal: %{"type" => "number", "format" => "double"},
    boolean: %{"type" => "boolean"},
    date: %{"type" => "string", "format" => "date"},
    time: %{"type" => "string", "format" => "time"},
    datetime: %{"type" => "string", "format" => "date-time"},
    utc_datetime: %{"type" => "string", "format" => "date-time"},
    utc_datetime_usec: %{"type" => "string", "format" => "date-time"},
    naive_datetime: %{"type" => "string", "format" => "date-time"},
    uuid: %{"type" => "string", "format" => "uuid"},
    binary: %{"type" => "string", "format" => "binary"},
    map: %{"type" => "object"},
    atom: %{"type" => "string"},
    term: %{},
    file: %{"type" => "string", "format" => "binary", "description" => "File content (binary)"},
    duration_name: %{
      "type" => "string",
      "enum" => ~w(year month week day hour minute second millisecond microsecond nanosecond),
      "description" => "Duration unit name"
    }
  }

  # Convert Ash type to base JSON Schema
  defp ash_type_to_base_schema(type) do
    normalized = normalize_type(type)
    simple_type_schema(normalized) || complex_type_schema(normalized)
  end

  # Handle simple atom types via map lookup
  defp simple_type_schema(type) when is_atom(type), do: Map.get(@simple_type_schemas, type)
  defp simple_type_schema(_), do: nil

  # Handle complex/tuple types
  defp complex_type_schema({:array, inner_type}) do
    %{"type" => "array", "items" => ash_type_to_base_schema(inner_type)}
  end

  defp complex_type_schema({:embedded, module}) do
    schema_name = module |> Module.split() |> List.last()
    %{"$ref" => "#/components/schemas/#{schema_name}"}
  end

  defp complex_type_schema({:union, types}), do: build_union_schema(types)
  defp complex_type_schema({:struct, module}), do: build_struct_schema(module)
  defp complex_type_schema({:custom, custom_schema}), do: custom_schema
  defp complex_type_schema(_), do: %{"type" => "string"}

  # Build union type schema using anyOf
  defp build_union_schema(types) when is_list(types) do
    any_of =
      Enum.map(types, fn
        {name, type_config} when is_list(type_config) ->
          inner_type = Keyword.get(type_config, :type, :string)
          schema = ash_type_to_base_schema(inner_type)
          Map.put(schema, "title", to_string(name))

        type when is_atom(type) ->
          ash_type_to_base_schema(type)

        _ ->
          %{"type" => "string"}
      end)

    %{"anyOf" => any_of}
  end

  defp build_union_schema(_), do: %{}

  # Build struct type schema
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

  # Known basic atom types
  @basic_types ~w(string ci_string integer float decimal boolean date time datetime
                  utc_datetime utc_datetime_usec naive_datetime uuid binary map atom
                  term file duration_name)a

  # Map of Ash.Type.* modules to their atom equivalents
  @ash_type_to_atom %{
    Ash.Type.String => :string,
    Ash.Type.CiString => :ci_string,
    Ash.Type.Integer => :integer,
    Ash.Type.Float => :float,
    Ash.Type.Decimal => :decimal,
    Ash.Type.Boolean => :boolean,
    Ash.Type.Date => :date,
    Ash.Type.Time => :time,
    Ash.Type.DateTime => :datetime,
    Ash.Type.UtcDatetime => :utc_datetime,
    Ash.Type.UtcDatetimeUsec => :utc_datetime_usec,
    Ash.Type.NaiveDatetime => :naive_datetime,
    Ash.Type.UUID => :uuid,
    Ash.Type.Binary => :binary,
    Ash.Type.Map => :map,
    Ash.Type.Atom => :atom,
    Ash.Type.Term => :term,
    Ash.Type.File => :file,
    Ash.Type.DurationName => :duration_name
  }

  # Handle union types
  defp normalize_type({:union, types}), do: {:union, types}

  # Handle struct types
  defp normalize_type({:struct, module}), do: {:struct, module}

  # Handle embedded types (produced by recursive normalization)
  defp normalize_type({:embedded, module}), do: {:embedded, module}

  # Handle array types
  defp normalize_type({:array, inner}), do: {:array, normalize_type(inner)}

  # Handle tuple types (legacy format) - first element is the type module
  defp normalize_type(type) when is_tuple(type) do
    Map.get(@ash_type_to_atom, elem(type, 0), :string)
  end

  # Check if a type is a basic atom, Ash.Type module, embedded resource, or custom type
  defp normalize_type(type) when is_atom(type) do
    cond do
      type in @basic_types -> type
      Map.has_key?(@ash_type_to_atom, type) -> Map.get(@ash_type_to_atom, type)
      true -> normalize_complex_type(type)
    end
  end

  # Fallback for unknown types
  defp normalize_type(_), do: :string

  # Handle complex type checking for embedded resources, custom types, and unions
  defp normalize_complex_type(type) do
    cond do
      embedded_resource?(type) ->
        {:embedded, type}

      has_json_schema_callback?(type) ->
        {:custom, get_custom_json_schema(type)}

      union_result = get_union_types(type) ->
        union_result

      true ->
        :string
    end
  end

  # Check if a type has a json_schema/1 callback
  # Only called from normalize_complex_type which guarantees type is an atom
  defp has_json_schema_callback?(type) do
    Code.ensure_loaded?(type) and function_exported?(type, :json_schema, 1)
  end

  # Get the JSON schema from a custom type's json_schema/1 callback
  defp get_custom_json_schema(type) do
    type.json_schema([])
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

  # Checks if a type is an embedded Ash resource
  @spec embedded_resource?(atom()) :: boolean()
  defp embedded_resource?(type) when is_atom(type) do
    Code.ensure_loaded?(type) and
      function_exported?(type, :spark_is, 0) and
      Spark.Dsl.is?(type, Ash.Resource) and
      ash_embedded?(type)
  end

  # Checks if a resource is embedded using Ash.Resource.Info.embedded?/1
  # Called only after confirming the resource is a valid Ash.Resource via Spark.Dsl.is?
  @spec ash_embedded?(atom()) :: boolean()
  defp ash_embedded?(resource), do: Ash.Resource.Info.embedded?(resource)

  # Check if attribute allows nil
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
  defp make_nullable_30(schema) do
    Map.put(schema, "nullable", true)
  end

  # Add constraints from Ash attribute
  defp maybe_add_constraints(schema, %{constraints: constraints}) when is_list(constraints) do
    Enum.reduce(constraints, schema, fn
      {:min_length, min}, acc ->
        Map.put(acc, "minLength", min)

      {:max_length, max}, acc ->
        Map.put(acc, "maxLength", max)

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
        # Convert atom values to strings for JSON Schema compatibility
        string_values = Enum.map(values, &to_string/1)
        Map.put(acc, "enum", string_values)

      _, acc ->
        acc
    end)
  end

  defp maybe_add_constraints(schema, _), do: schema

  # Add description
  defp maybe_add_description(schema, %{description: desc}) when is_binary(desc) do
    Map.put(schema, "description", desc)
  end

  defp maybe_add_description(schema, _), do: schema

  # Add default value (skip nil and function defaults - they can't be represented in OpenAPI)
  defp maybe_add_default(schema, %{default: default})
       when default != nil and not is_function(default) do
    Map.put(schema, "default", default)
  end

  defp maybe_add_default(schema, _), do: schema

  # Ensures a value is a number (for minimum/maximum constraints)
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
