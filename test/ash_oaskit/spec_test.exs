defmodule AshOaskit.SpecTest do
  @moduledoc """
  Tests for spec modules defined with `use AshOaskit`.

  Covers spec generation, option validation, persistent_term caching
  (including the per-module and global kill switches, and
  `cache_variant/0` keying), the `modify_spec/1` hook, and the deep
  oaskit-alignment regression: generated specs must survive
  `Oaskit.build_spec!/2` (Normalizer + JSV operation building).
  """

  use ExUnit.Case, async: false

  doctest AshOaskit.Spec

  defmodule BlogSpec do
    @moduledoc false
    use AshOaskit,
      domains: [AshOaskit.Test.Blog],
      title: "Blog API",
      api_version: "2.0.0"
  end

  defmodule Blog30Spec do
    @moduledoc false
    use AshOaskit,
      domains: [AshOaskit.Test.Blog],
      version: "3.0"
  end

  defmodule UncachedSpec do
    @moduledoc false
    use AshOaskit,
      domains: [AshOaskit.Test.Blog],
      cache: false
  end

  defmodule ModifiedSpec do
    @moduledoc false
    use AshOaskit, domains: [AshOaskit.Test.Blog]

    @impl AshOaskit.Spec
    def modify_spec(spec) do
      put_in(spec, ["components", "securitySchemes"], %{
        "bearerAuth" => %{"type" => "http", "scheme" => "bearer"}
      })
    end
  end

  defmodule VariantSpec do
    @moduledoc false
    use AshOaskit, domains: [AshOaskit.Test.Blog]

    @impl Oaskit
    def cache_variant, do: Process.get(:variant_spec_tenant)
  end

  defmodule BuilderSpec do
    @moduledoc false
    use AshOaskit,
      domains: [AshOaskit.Test.Blog],
      title: "Builder API",
      api_version: "9.9.9",
      spec_builder: AshOaskit.SpecBuilder.Default,
      cache: false
  end

  setup do
    for module <- [BlogSpec, Blog30Spec, ModifiedSpec, VariantSpec] do
      :persistent_term.erase({:ash_oaskit_cache, module, nil})
    end

    :ok
  end

  describe "spec/0" do
    test "generates a normalized spec from the configured domains" do
      spec = BlogSpec.spec()

      assert spec["openapi"] == "3.1.0"
      assert spec["info"]["title"] == "Blog API"
      assert spec["info"]["version"] == "2.0.0"
      assert Map.has_key?(spec["paths"], "/posts")
    end

    test "honors the :version option" do
      assert Blog30Spec.spec()["openapi"] == "3.0.3"
    end

    test "routes through a custom spec builder" do
      spec = BuilderSpec.spec()

      assert spec["info"]["title"] == "Builder API"
      assert spec["info"]["version"] == "9.9.9"
    end

    test "exposes the use options for introspection" do
      assert BlogSpec.__ash_oaskit__()[:title] == "Blog API"
    end
  end

  describe "option validation" do
    test "raises on unknown options" do
      assert_raise ArgumentError, ~r/unknown option/, fn ->
        defmodule BadOption do
          use AshOaskit, domains: [AshOaskit.Test.Blog], titel: "typo"
        end
      end
    end

    test "raises on missing domains" do
      assert_raise ArgumentError, ~r/non-empty :domains/, fn ->
        defmodule NoDomains do
          use AshOaskit, title: "API"
        end
      end
    end

    test "raises on empty domains" do
      assert_raise ArgumentError, ~r/non-empty :domains/, fn ->
        defmodule EmptyDomains do
          use AshOaskit, domains: []
        end
      end
    end

    test "raises on unsupported versions" do
      assert_raise ArgumentError, ~r/unsupported :version/, fn ->
        defmodule BadVersion do
          use AshOaskit, domains: [AshOaskit.Test.Blog], version: "2.0"
        end
      end
    end
  end

  describe "caching" do
    test "caches the generated spec in persistent_term" do
      key = {:ash_oaskit_cache, BlogSpec, nil}
      assert :persistent_term.get(key, :missing) == :missing

      spec = BlogSpec.spec()

      assert :persistent_term.get(key, :missing) == spec
      assert BlogSpec.spec() == spec
    end

    test "cache: false bypasses the cache" do
      key = {:ash_oaskit_cache, UncachedSpec, nil}
      UncachedSpec.spec()

      assert :persistent_term.get(key, :missing) == :missing
    end

    test "config :ash_oaskit, cache_specs: false bypasses the cache globally" do
      Application.put_env(:ash_oaskit, :cache_specs, false)
      on_exit(fn -> Application.delete_env(:ash_oaskit, :cache_specs) end)

      key = {:ash_oaskit_cache, BlogSpec, nil}
      BlogSpec.spec()

      assert :persistent_term.get(key, :missing) == :missing
    end

    test "cache_variant/0 keys the cache" do
      Process.put(:variant_spec_tenant, :tenant_a)
      on_exit(fn -> Process.delete(:variant_spec_tenant) end)
      on_exit(fn -> :persistent_term.erase({:ash_oaskit_cache, VariantSpec, :tenant_a}) end)

      VariantSpec.spec()

      assert :persistent_term.get({:ash_oaskit_cache, VariantSpec, :tenant_a}, :missing) !=
               :missing
    end
  end

  describe "modify_spec/1" do
    test "is applied to the generated spec and cached" do
      spec = ModifiedSpec.spec()

      assert spec["components"]["securitySchemes"]["bearerAuth"]["scheme"] == "bearer"

      cached = :persistent_term.get({:ash_oaskit_cache, ModifiedSpec, nil}, :missing)
      assert cached["components"]["securitySchemes"]["bearerAuth"]
    end
  end

  describe "oaskit integration" do
    test "Oaskit.build_spec!/1 accepts generated specs end to end" do
      # Proves the generated spec survives Oaskit's Normalizer and the
      # JSV-based operation builder — the deep-alignment regression
      assert {operations, _} = Oaskit.build_spec!(BlogSpec)
      assert is_map(operations)
      assert map_size(operations) > 0
    end

    test "Oaskit.build_spec!/1 accepts 3.0 specs" do
      assert {operations, _} = Oaskit.build_spec!(Blog30Spec)
      assert map_size(operations) > 0
    end

    test "Oaskit.to_json!/1 renders the spec module" do
      json = Oaskit.to_json!(BlogSpec)

      assert json =~ ~s("openapi")
      assert json =~ ~s(Blog API)
    end
  end
end
