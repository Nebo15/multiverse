defmodule MultiverseTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Multiverse

  use ExUnit.Case, async: true
  use Plug.Test

  defmodule ChangeOne do
    use Multiverse.ChangeFactory
  end

  defmodule ChangeTwo do
    use Multiverse.ChangeFactory
  end

  defmodule ChangeThree do
    use Multiverse.ChangeFactory
  end

  defmodule ChangeFour do
    use Multiverse.ChangeFactory
  end

  defmodule MissbehavingAdapter do
    def init(_adapter, _opts), do: :error
  end

  setup do
    %{conn: conn(:get, "/foo")}
  end

  describe "init/1" do
    test "raises when adapter is not loaded" do
      assert_raise ArgumentError, ~r/NotLoadedAdapter was not compiled/, fn ->
        Multiverse.init(adapter: NotLoadedAdapter)
      end
    end

    test "raises when adapter can not be initialized not loaded" do
      assert_raise ArgumentError, ~r/Can not initialize MultiverseTest.MissbehavingAdapter/, fn ->
        Multiverse.init(adapter: MissbehavingAdapter)
      end
    end

    test "falls back to default adapter" do
      %{adapter: Multiverse.Adapters.ISODate} = Multiverse.init([])
    end

    test "falls back to default version header" do
      %{version_header: "x-api-version"} = Multiverse.init([])
    end

    test "allows to override version header" do
      %{version_header: "custom-version-header"} = Multiverse.init(version_header: "custom-version-header")
    end

    test "raises when change is not loaded" do
      assert_raise ArgumentError, ~r/NotLoadedChange was not compiled/, fn ->
        Multiverse.init(gates: [{~D[2001-01-01], [NotLoadedChange]}])
      end
    end

    test "resolves options from application environment" do
      env = [
        adapter: Multiverse.Adapters.ISODate,
        gates: [{~D[2001-01-01], [ChangeOne]}],
        version_header: "custom-version-header"
      ]

      Application.put_env(:multiverse, MyEndpoint, env)

      assert Multiverse.init(endpoint: MyEndpoint) ==
               %{
                 version_header: "custom-version-header",
                 gates: [{~D[2001-01-01], [ChangeOne]}],
                 adapter: Multiverse.Adapters.ISODate
               }

      Application.put_env(:multiverse, MyEndpoint, adapter: MyAdapter)

      assert_raise ArgumentError, ~r/MyAdapter was not compiled/, fn ->
        Multiverse.init(endpoint: MyEndpoint)
      end
    end

    test "resolves configuration via adapter init/2 callback" do
      %{version_header: "test-adapter-version-header"} = Multiverse.init(adapter: Multiverse.TestAdapter)
    end
  end

  describe "call/2" do
    test "works with default options", %{conn: conn} do
      config = Multiverse.init([])
      conn = Multiverse.call(conn, config)

      assert conn.assigns == %{}
      assert conn.before_send == []

      # Stores %Multiverse.VersionSchema{} in conn.private
      assert conn.private.multiverse_version_schema ==
               %Multiverse.VersionSchema{changes: [], adapter: Multiverse.Adapters.ISODate, version: Date.utc_today()}
    end

    test "handles empty gates", %{conn: conn} do
      config = %{adapter: Multiverse.Adapters.ISODate, gates: [], version_header: "x-api-version"}
      conn = Multiverse.call(conn, config)
      assert conn.assigns == %{}
      assert conn.before_send == []
    end

    test "resolves empty version to current gate", %{conn: conn} do
      config = %{adapter: Multiverse.Adapters.ISODate, gates: [], version_header: "x-api-version"}

      conn = %{conn | req_headers: [{"x-api-version", ""}]}
      conn = Multiverse.call(conn, config)

      assert conn.private.multiverse_version_schema.version == Date.utc_today()
    end

    test "applies changes in correct order", %{conn: conn} do
      config = %{
        adapter: Multiverse.Adapters.ISODate,
        gates: [
          {~D[2002-03-01], [ChangeThree]},
          {~D[2001-02-01], [ChangeOne, ChangeTwo]}
        ],
        version_header: "x-api-version"
      }

      conn = %{conn | req_headers: [{"x-api-version", "2001-01-01"}]}

      conn =
        conn
        |> Multiverse.call(config)
        |> send_resp(204, "")

      assert length(conn.private.multiverse_version_schema.changes) == 3
      assert Multiverse.Change.active?(conn, MultiverseTest.ChangeOne)
      assert Multiverse.Change.active?(conn, MultiverseTest.ChangeTwo)
      assert Multiverse.Change.active?(conn, MultiverseTest.ChangeThree)

      assert conn.assigns.applied_changes ==
               [
                 :"Elixir.MultiverseTest.ChangeOne.handle_request",
                 :"Elixir.MultiverseTest.ChangeTwo.handle_request",
                 :"Elixir.MultiverseTest.ChangeThree.handle_request",
                 :"Elixir.MultiverseTest.ChangeThree.handle_response",
                 :"Elixir.MultiverseTest.ChangeTwo.handle_response",
                 :"Elixir.MultiverseTest.ChangeOne.handle_response"
               ]

      assert length(conn.before_send) == 3
    end

    test "does not apply changes occurred on a specified date", %{conn: conn} do
      config = %{
        adapter: Multiverse.Adapters.ISODate,
        gates: [
          {~D[2002-03-01], [ChangeThree]},
          {~D[2001-02-01], [ChangeOne, ChangeTwo]}
        ],
        version_header: "x-api-version"
      }

      conn = %{conn | req_headers: [{"x-api-version", "2001-02-01"}]}

      conn =
        conn
        |> Multiverse.call(config)
        |> send_resp(204, "")

      refute Multiverse.Change.active?(conn, MultiverseTest.ChangeOne)
      refute Multiverse.Change.active?(conn, MultiverseTest.ChangeTwo)
      assert Multiverse.Change.active?(conn, MultiverseTest.ChangeThree)

      assert conn.assigns.applied_changes ==
               [
                 :"Elixir.MultiverseTest.ChangeThree.handle_request",
                 :"Elixir.MultiverseTest.ChangeThree.handle_response"
               ]

      assert length(conn.before_send) == 1
    end

    test "ignores older changes", %{conn: conn} do
      config = %{
        adapter: Multiverse.Adapters.ISODate,
        gates: [
          {~D[2002-03-01], [ChangeThree]},
          {~D[2001-02-01], [ChangeOne, ChangeTwo]}
        ],
        version_header: "x-api-version"
      }

      conn = %{conn | req_headers: [{"x-api-version", "2001-02-02"}]}

      conn =
        conn
        |> Multiverse.call(config)
        |> send_resp(204, "")

      refute Multiverse.Change.active?(conn, MultiverseTest.ChangeOne)
      refute Multiverse.Change.active?(conn, MultiverseTest.ChangeTwo)
      assert Multiverse.Change.active?(conn, MultiverseTest.ChangeThree)

      assert conn.assigns.applied_changes ==
               [
                 :"Elixir.MultiverseTest.ChangeThree.handle_request",
                 :"Elixir.MultiverseTest.ChangeThree.handle_response"
               ]

      assert length(conn.before_send) == 1
    end

    test "does not affect edge consumers", %{conn: conn} do
      config = %{
        adapter: Multiverse.Adapters.ISODate,
        gates: [
          {~D[2002-03-01], [ChangeThree]},
          {~D[2001-02-01], [ChangeOne, ChangeTwo]}
        ],
        version_header: "x-api-version"
      }

      conn = %{conn | req_headers: [{"x-api-version", "edge"}]}

      conn =
        conn
        |> Multiverse.call(config)
        |> send_resp(204, "")

      assert conn.private.multiverse_version_schema.changes == []
      refute Map.get(conn.assigns, :applied_changes)
      assert conn.before_send == []
    end
  end
end
