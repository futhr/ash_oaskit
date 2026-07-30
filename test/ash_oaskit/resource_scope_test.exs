defmodule AshOaskit.ResourceScopeTest do
  @moduledoc false

  use ExUnit.Case, async: true

  defp schema_names(spec) do
    spec |> get_in(["components", "schemas"]) |> Map.keys()
  end

  defp tag_names(spec) do
    Enum.map(spec["tags"] || [], & &1["name"])
  end

  describe ":all (default)" do
    test "seeds every domain resource into schemas" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped])

      names = schema_names(spec)
      assert Enum.any?(names, &String.starts_with?(&1, "Device"))
      assert Enum.any?(names, &String.starts_with?(&1, "Site"))
      assert Enum.any?(names, &String.starts_with?(&1, "AuditLog"))
    end

    test "tags every domain resource" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped])

      assert "Device" in tag_names(spec)
      assert "Site" in tag_names(spec)
      assert "AuditLog" in tag_names(spec)
    end

    test ":all may be passed explicitly with identical output" do
      default = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped])
      explicit = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped], resource_scope: :all)

      assert default == explicit
    end
  end

  describe ":routed" do
    test "drops unrouted, unreferenced resources from schemas" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped], resource_scope: :routed)

      names = schema_names(spec)
      assert Enum.any?(names, &String.starts_with?(&1, "Device"))
      refute Enum.any?(names, &String.starts_with?(&1, "AuditLog"))
    end

    test "keeps unrouted resources referenced through relationships" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped], resource_scope: :routed)

      assert Enum.any?(schema_names(spec), &String.starts_with?(&1, "Site"))
    end

    test "tags only routed resources" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped], resource_scope: :routed)

      assert tag_names(spec) == ["Device"]
    end

    test "routed paths are unaffected by the scope" do
      all = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped])
      routed = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped], resource_scope: :routed)

      assert routed["paths"] == all["paths"]
      assert Map.has_key?(routed["paths"], "/devices")
    end

    test "the scoped spec validates against the OpenAPI schema" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Scoped], resource_scope: :routed)

      assert {:ok, _} = AshOaskit.validate(spec)
    end
  end

  describe "option validation" do
    test "rejects unknown scopes at use time" do
      assert_raise ArgumentError, ~r/unsupported :resource_scope/, fn ->
        AshOaskit.Spec.validate_opts!(
          [domains: [AshOaskit.Test.Scoped], resource_scope: :public],
          __MODULE__
        )
      end
    end

    test "accepts :routed at use time" do
      opts = [domains: [AshOaskit.Test.Scoped], resource_scope: :routed]

      assert ^opts = AshOaskit.Spec.validate_opts!(opts, __MODULE__)
    end
  end
end
