defmodule AshOaskit.Core.PathUtils do
  @moduledoc """
  Shared path and route string utilities.

  Provides common functions for working with route paths and operation names.
  These utilities convert between Phoenix-style route syntax (`:id`) and
  OpenAPI-style path templates (`{id}`), extract parameter names for schema
  generation, and humanize operation identifiers for display.

  ## Usage

  Import in any module that manipulates route paths:

      import AshOaskit.Core.PathUtils

      path = "/posts/:post_id/comments/:id"
      openapi_path = convert_path_params(path)
      #=> "/posts/{post_id}/comments/{id}"

      params = extract_path_params(path)
      #=> ["post_id", "id"]

  ## Callers

  | Module | Functions used |
  |--------|---------------|
  | `PathBuilder` | `humanize/1`, `extract_path_params/1`, `convert_path_params/1` |
  | `PhoenixIntrospection` | `humanize/1`, `extract_path_params/1`, `convert_path_params/1` |
  | `RouteOperations` | `humanize/1`, `extract_path_params/1` |

  ## Examples

      iex> AshOaskit.Core.PathUtils.convert_path_params("/users/:user_id/posts/:id")
      "/users/{user_id}/posts/{id}"

      iex> AshOaskit.Core.PathUtils.extract_path_params("/users/:user_id/posts/:id")
      ["user_id", "id"]

      iex> AshOaskit.Core.PathUtils.humanize("list_posts")
      "List Posts"
  """

  @doc """
  Humanizes an underscore-separated string into title case.

  Splits on underscores and capitalizes each word. Used to generate
  human-readable operation summaries and tag names from Ash action names.

  ## Parameters

    - `string` - An underscore-separated identifier (e.g., an Ash action name)

  ## Examples

      iex> AshOaskit.Core.PathUtils.humanize("create_user")
      "Create User"

      iex> AshOaskit.Core.PathUtils.humanize("list_all_posts")
      "List All Posts"

      iex> AshOaskit.Core.PathUtils.humanize("index")
      "Index"
  """
  @spec humanize(String.t()) :: String.t()
  def humanize(string) do
    string
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Extracts path parameter names from a route path.

  Scans for Phoenix-style `:param` segments and returns the parameter names
  in order of appearance. Used to generate OpenAPI path parameter objects.

  ## Parameters

    - `path` - A Phoenix-style route path string

  ## Examples

      iex> AshOaskit.Core.PathUtils.extract_path_params("/posts/:id")
      ["id"]

      iex> AshOaskit.Core.PathUtils.extract_path_params("/posts/:post_id/comments/:id")
      ["post_id", "id"]

      iex> AshOaskit.Core.PathUtils.extract_path_params("/posts")
      []
  """
  @spec extract_path_params(String.t()) :: [String.t()]
  def extract_path_params(path) do
    ~r/:([a-zA-Z_]+)/
    |> Regex.scan(path)
    |> Enum.map(fn [_, name] -> name end)
  end

  @doc """
  Converts Phoenix-style path params (`:id`) to OpenAPI format (`{id}`).

  Replaces all `:param` segments with `{param}` template syntax as required
  by the OpenAPI Path Templating specification.

  ## Parameters

    - `path` - A Phoenix-style route path string

  ## Examples

      iex> AshOaskit.Core.PathUtils.convert_path_params("/posts/:id")
      "/posts/{id}"

      iex> AshOaskit.Core.PathUtils.convert_path_params("/posts/:post_id/comments/:id")
      "/posts/{post_id}/comments/{id}"

      iex> AshOaskit.Core.PathUtils.convert_path_params("/posts")
      "/posts"
  """
  @spec convert_path_params(String.t()) :: String.t()
  def convert_path_params(path) do
    Regex.replace(~r/:([a-zA-Z_]+)/, path, "{\\1}")
  end
end
