defmodule Multiverse.Adapters.ISODateTest do
  use ExUnit.Case, async: true
  use Plug.Test

  setup do
    %{conn: conn(:get, "/foo")}
  end

  test "chronologically orders gates" do
    assert %{gates: gates} =
      Multiverse.init(gates: %{
        ~D[2002-03-01] => [],
        ~D[2001-02-01] => [],
        ~D[2001-01-01] => [],
        ~D[2001-02-02] => [],
      })

    assert gates ==
      %{
        ~D[2001-01-01] => [],
        ~D[2001-02-01] => [],
        ~D[2001-02-02] => [],
        ~D[2002-03-01] => [],
      }
  end

  test "fetches API version from date in x-api-version header", %{conn: conn} do
    opts = %{adapter: Multiverse.Adapters.ISODate, gates: %{}, version_header: "x-api-version"}

    conn = %{conn | req_headers: [{"x-api-version", "2001-01-01"}]}
    conn = Multiverse.call(conn, opts)

    assert conn.private.multiverse_version_schema.version == ~D[2001-01-01]
  end

  test "resolves latest channel to current date", %{conn: conn} do
    opts = %{adapter: Multiverse.Adapters.ISODate, gates: %{}, version_header: "x-api-version"}

    conn = %{conn | req_headers: [{"x-api-version", "latest"}]}
    conn = Multiverse.call(conn, opts)

    assert conn.private.multiverse_version_schema.version == Date.utc_today()
  end

  test "resolves edge channel to latest gate", %{conn: conn} do
    opts = %{
      adapter: Multiverse.Adapters.ISODate,
      gates: %{
        ~D[2002-03-01] => [],
        ~D[2001-02-01] => [],
      },
      version_header: "x-api-version"
    }

    conn = %{conn | req_headers: [{"x-api-version", "edge"}]}
    conn = Multiverse.call(conn, opts)

    assert conn.private.multiverse_version_schema.version == "edge"
  end

  test "resolves malformed version to current gate", %{conn: conn} do
    opts = %{adapter: Multiverse.Adapters.ISODate, gates: %{}, version_header: "x-api-version"}

    conn = %{conn | req_headers: [{"x-api-version", "not-a-date"}]}
    conn = Multiverse.call(conn, opts)

    assert conn.private.multiverse_version_schema.version == Date.utc_today()
  end

  test "fetches API version from custom header", %{conn: conn} do
    opts = %{adapter: Multiverse.Adapters.ISODate, gates: %{}, version_header: "x-my-api-version"}

    conn = %{conn | req_headers: [{"x-my-api-version", "2001-01-01"}]}
    conn = Multiverse.call(conn, opts)

    assert conn.private.multiverse_version_schema.version == ~D[2001-01-01]
  end
end
