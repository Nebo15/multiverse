defmodule MultiverseTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Multiverse.Change
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

    test "raises when adapter returns malformed response" do
      assert_raise ArgumentError, ~r/Can not initialize MultiverseTest.MissbehavingAdapter/, fn ->
        Multiverse.init(adapter: MissbehavingAdapter)
      end
    end

    test "falls back to default adapter" do
      %{adapter: Multiverse.Adapters.ISODate} = Multiverse.init(default_version: :latest)
    end

    test "falls back to default version header" do
      %{version_header: "x-api-version"} = Multiverse.init(default_version: :latest)
    end

    test "allows to override version header" do
      opts = [default_version: :latest, version_header: "custom-version-header"]
      %{version_header: "custom-version-header"} = Multiverse.init(opts)
    end

    test "raises when change is not loaded" do
      assert_raise ArgumentError, ~r/NotLoadedChange was not compiled/, fn ->
        Multiverse.init(default_version: :latest, gates: [{~D[2001-01-01], [NotLoadedChange]}])
      end
    end

    test "reads configuration from application environment" do
      env = [
        adapter: Multiverse.Adapters.ISODate,
        gates: [{~D[2001-01-01], [ChangeOne]}],
        version_header: "custom-version-header",
        default_version: :latest
      ]

      Application.put_env(:multiverse, MyEndpoint, env)

      assert Multiverse.init(endpoint: MyEndpoint) ==
               %{
                 version_header: "custom-version-header",
                 gates: [{~D[2001-01-01], [ChangeOne]}],
                 adapter: Multiverse.Adapters.ISODate,
                 adapter_config: [
                   gates: [{~D[2001-01-01], [ChangeOne]}],
                   endpoint: MyEndpoint,
                   version_header: "custom-version-header",
                   default_version: :latest
                 ]
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
    test "requires only adapter options", %{conn: conn} do
      config = Multiverse.init(default_version: :latest)
      conn = Multiverse.call(conn, config)
      assert conn.assigns == %{}
      assert conn.before_send == []
    end

    test "stores version schema in conn.private", %{conn: conn} do
      config = Multiverse.init(default_version: :latest)
      conn = Multiverse.call(conn, config)

      assert conn.private.multiverse_version_schema ==
               %Multiverse.VersionSchema{changes: [], adapter: Multiverse.Adapters.ISODate, version: Date.utc_today()}
    end

    test "fetches consumer version from headers", %{conn: conn} do
      config = Multiverse.init(version_header: "x-my-api-version", default_version: :latest)
      conn = %{conn | req_headers: [{"x-my-api-version", "2001-01-01"}]}
      conn = Multiverse.call(conn, config)
      assert conn.private.multiverse_version_schema.version == ~D[2001-01-01]
    end

    test "applies changes in chronological order", %{conn: conn} do
      config =
        Multiverse.init(
          default_version: :latest,
          gates: [
            {~D[2002-03-01], [ChangeThree]},
            {~D[2001-02-01], [ChangeOne, ChangeTwo]}
          ]
        )

      conn = %{conn | req_headers: [{"x-api-version", "2001-01-01"}]}

      conn =
        conn
        |> Multiverse.call(config)
        |> send_resp(204, "")

      assert length(conn.private.multiverse_version_schema.changes) == 3
      assert Change.active?(conn, MultiverseTest.ChangeOne)
      assert Change.active?(conn, MultiverseTest.ChangeTwo)
      assert Change.active?(conn, MultiverseTest.ChangeThree)

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

    test "does not apply changes occurred on a specified version", %{conn: conn} do
      config =
        Multiverse.init(
          default_version: :latest,
          gates: [
            {~D[2002-03-01], [ChangeThree]},
            {~D[2001-02-01], [ChangeOne, ChangeTwo]}
          ]
        )

      conn = %{conn | req_headers: [{"x-api-version", "2001-02-01"}]}

      conn =
        conn
        |> Multiverse.call(config)
        |> send_resp(204, "")

      refute Change.active?(conn, MultiverseTest.ChangeOne)
      refute Change.active?(conn, MultiverseTest.ChangeTwo)
      assert Change.active?(conn, MultiverseTest.ChangeThree)

      assert conn.assigns.applied_changes ==
               [
                 :"Elixir.MultiverseTest.ChangeThree.handle_request",
                 :"Elixir.MultiverseTest.ChangeThree.handle_response"
               ]

      assert length(conn.before_send) == 1
    end

    test "does not apply older changes", %{conn: conn} do
      config =
        Multiverse.init(
          default_version: :latest,
          gates: [
            {~D[2002-03-01], [ChangeThree]},
            {~D[2001-02-01], [ChangeOne, ChangeTwo]}
          ]
        )

      conn = %{conn | req_headers: [{"x-api-version", "2001-02-02"}]}

      conn =
        conn
        |> Multiverse.call(config)
        |> send_resp(204, "")

      refute Change.active?(conn, MultiverseTest.ChangeOne)
      refute Change.active?(conn, MultiverseTest.ChangeTwo)
      assert Change.active?(conn, MultiverseTest.ChangeThree)

      assert conn.assigns.applied_changes ==
               [
                 :"Elixir.MultiverseTest.ChangeThree.handle_request",
                 :"Elixir.MultiverseTest.ChangeThree.handle_response"
               ]

      assert length(conn.before_send) == 1
    end
  end
end
