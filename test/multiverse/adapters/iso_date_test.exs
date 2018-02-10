defmodule Multiverse.Adapters.ISODateTest do
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

  setup do
    %{conn: conn(:get, "/foo")}
  end

  test "raises when default_version is not set" do
    assert_raise ArgumentError, "Multiverse.Adapters.ISODate :default_version config is not set", fn ->
      Multiverse.init([])
    end
  end

  test "raises on invalid default_version value" do
    message =
      "invalid Multiverse.Adapters.ISODate :default_version config value, " <>
        "possible values: :latest, :oldest, got: :invalid"

    assert_raise ArgumentError, message, fn ->
      Multiverse.init(default_version: :invalid)
    end
  end

  test "orders gates in a reverse chronological order" do
    %{gates: gates} =
      Multiverse.init(
        gates: %{
          ~D[2002-03-01] => [],
          ~D[2001-02-01] => [],
          ~D[2001-01-01] => [],
          ~D[2001-02-02] => []
        },
        default_version: :latest
      )

    assert gates ==
             [
               {~D[2002-03-01], []},
               {~D[2001-02-02], []},
               {~D[2001-02-01], []},
               {~D[2001-01-01], []}
             ]
  end

  test "resolves empty version to current date on default_version: :latest", %{conn: conn} do
    config = Multiverse.init(default_version: :latest)
    conn = %{conn | req_headers: [{"x-api-version", ""}]}
    conn = Multiverse.call(conn, config)
    assert conn.private.multiverse_version_schema.version == Date.utc_today()
  end

  test "resolves empty version to one day before first gate on default_version: :oldest", %{conn: conn} do
    today = Date.utc_today()
    tomorrow = Date.add(today, 1)

    config =
      Multiverse.init(
        default_version: :oldest,
        gates: [
          {tomorrow, [ChangeThree]},
          {today, [ChangeTwo]},
          {~D[2001-02-01], [ChangeOne]}
        ]
      )

    conn = %{conn | req_headers: [{"x-api-version", ""}]}
    conn = Multiverse.call(conn, config)
    assert conn.private.multiverse_version_schema.version == ~D[2001-01-31]
  end

  test "resolves empty version to current date on default_version: :oldest and no empty gates", %{conn: conn} do
    config = Multiverse.init(default_version: :oldest)
    conn = %{conn | req_headers: [{"x-api-version", ""}]}
    conn = Multiverse.call(conn, config)
    assert conn.private.multiverse_version_schema.version == Date.utc_today()
  end

  test "resolves malformed version to default", %{conn: conn} do
    config = Multiverse.init(default_version: :latest)
    conn = %{conn | req_headers: [{"x-api-version", "not-a-date"}]}
    conn = Multiverse.call(conn, config)
    assert conn.private.multiverse_version_schema.version == Date.utc_today()
  end

  test "fetches API version from date in x-api-version header", %{conn: conn} do
    config = Multiverse.init(default_version: :latest)
    conn = %{conn | req_headers: [{"x-api-version", "2001-01-01"}]}
    conn = Multiverse.call(conn, config)
    assert conn.private.multiverse_version_schema.version == ~D[2001-01-01]
  end

  test "resolves latest channel to current date", %{conn: conn} do
    config = Multiverse.init(default_version: :oldest)
    conn = %{conn | req_headers: [{"x-api-version", "latest"}]}
    conn = Multiverse.call(conn, config)
    assert conn.private.multiverse_version_schema.version == Date.utc_today()
  end

  test "does not apply any changes on edge version", %{conn: conn} do
    today = Date.utc_today()
    tomorrow = Date.add(today, 1)

    config =
      Multiverse.init(
        default_version: :latest,
        gates: [
          {tomorrow, [ChangeThree]},
          {today, [ChangeTwo]},
          {~D[2001-02-01], [ChangeOne]}
        ]
      )

    conn = %{conn | req_headers: [{"x-api-version", "edge"}]}

    conn =
      conn
      |> Multiverse.call(config)
      |> send_resp(204, "")

    assert conn.private.multiverse_version_schema.version == "edge"
    assert conn.private.multiverse_version_schema.changes == []
    refute Map.get(conn.assigns, :applied_changes)
    assert conn.before_send == []
  end
end
