defmodule AshOaskit.Core.PathUtils do
  @moduledoc """
  Shared path and route string utilities.

  Provides common functions for working with route paths and operation names
  used across path builders, Phoenix introspection, and route operations.
  """

  @doc """
  Humanizes an underscore-separated string into title case.

  ## Examples

      iex> AshOaskit.Core.PathUtils.humanize("create_user")
      "Create User"

      iex> AshOaskit.Core.PathUtils.humanize("list_all_posts")
      "List All Posts"
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

  Finds all `:param` style path parameters and returns their names.

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

  ## Examples

      iex> AshOaskit.Core.PathUtils.convert_path_params("/posts/:id")
      "/posts/{id}"

      iex> AshOaskit.Core.PathUtils.convert_path_params("/posts/:post_id/comments/:id")
      "/posts/{post_id}/comments/{id}"
  """
  @spec convert_path_params(String.t()) :: String.t()
  def convert_path_params(path) do
    Regex.replace(~r/:([a-zA-Z_]+)/, path, "{\\1}")
  end
end
