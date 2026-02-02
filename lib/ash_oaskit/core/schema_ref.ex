defmodule AshOaskit.Core.SchemaRef do
  @moduledoc """
  Builds OpenAPI `$ref` objects pointing to component schemas.

  Provides helper functions for constructing JSON Schema `$ref` references
  used throughout the OpenAPI specification. The `$ref` key is kept as a
  string because the Oaskit normalizer detects references by checking for
  the `"$ref"` string key.
  """

  @doc """
  Builds a `$ref` path string pointing to a component schema.

  ## Examples

      iex> AshOaskit.Core.SchemaRef.schema_ref_path("User")
      "#/components/schemas/User"
  """
  @spec schema_ref_path(String.t()) :: String.t()
  def schema_ref_path(name), do: "#/components/schemas/#{name}"

  @doc ~S"""
  Builds a JSON Schema `$ref` object pointing to a component schema.

  ## Examples

      iex> AshOaskit.Core.SchemaRef.schema_ref("User")
      %{"$ref" => "#/components/schemas/User"}
  """
  @spec schema_ref(String.t()) :: map()
  def schema_ref(name), do: %{"$ref" => schema_ref_path(name)}
end
