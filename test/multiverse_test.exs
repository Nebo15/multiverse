defmodule MultiverseTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Multiverse

  doctest Multiverse

  @version_header "x-api-version"

  defmodule GateSampleOne do
    @behaviour MultiverseGate

    def mutate_request(%Plug.Conn{query_params: query_params} = conn) do
      q = query_params
      |> Map.put("gate1_request_applied", true)
      |> Map.put("step", 1)

      %{conn | query_params: q}
    end

    def mutate_response(%Plug.Conn{query_params: query_params} = conn) do
      q = query_params
      |> Map.put("gate1_response_applied", true)
      |> Map.put("step", 4)

      %{conn | query_params: q}
    end
  end

  defmodule GateSampleTwo do
    @behaviour MultiverseGate

    def mutate_request(%Plug.Conn{query_params: query_params} = conn) do
      q = query_params
      |> Map.put("gate2_request_applied", true)
      |> Map.put("step", 2)

      %{conn | query_params: q}
    end

    def mutate_response(%Plug.Conn{query_params: query_params} = conn) do
      q = query_params
      |> Map.put("gate2_response_applied", true)
      |> Map.put("step", 3)

      %{conn | query_params: q}
    end
  end

  setup do
    [conn: conn(:get, "/foo")]
  end

  test "return connection without gates", context do
    version = "2016-01-01"
    gates = init([])

    assert %Plug.Conn{
      req_headers: [{"x-api-version", ^version}]
    } = context[:conn]
    |> insert_version_header(version)
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "defaults to current version", context do
    version = Timex.today
    |> Timex.format("{YYYY}-{0M}-{0D}")
    |> elem(1)

    gates = init([])

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version}
    } = context[:conn]
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "works with damaged versions", context do
    version = Timex.today
    |> Timex.format("{YYYY}-{0M}-{0D}")
    |> elem(1)

    gates = init([])

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version}
    } = context[:conn]
    |> insert_version_header("BADDATE")
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "applies error callback", context do
    version = custom_error_callback("", "")
    gates = init([
      error_callback: &custom_error_callback/2
    ])

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version}
    } = context[:conn]
    |> insert_version_header("BADDATE")
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "works with custom version header", context do
    version = "2016-01-01"
    gates = init([
      version_header: "x-custom-header"
    ])

    %{req_headers: req_headers} = context[:conn]
    conn = %Plug.Conn{context[:conn] | req_headers: [{"x-custom-header", version} | req_headers]}

    assert %Plug.Conn{
      req_headers: [{"x-custom-header", ^version}],
      assigns: %{client_api_version: ^version}
    } = conn
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "allows to bind to latest version", context do
    version = Timex.today
    |> Timex.format("{YYYY}-{0M}-{0D}")
    |> elem(1)
    gates = init([])

    assert %Plug.Conn{
      req_headers: [{"x-api-version", "latest"}],
      assigns: %{client_api_version: ^version}
    } = context[:conn]
    |> insert_version_header("latest")
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "assigns client api version", context do
    version = "2016-01-01"
    gates = init([])

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version}
    } = context[:conn]
    |> insert_version_header(version)
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "applies request gates", context do
    version = "2016-01-01"
    gates = init([gates: [
      "2016-02-01": MultiverseTest.GateSampleOne,
      "2016-03-01": MultiverseTest.GateSampleTwo
    ]])

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version},
      query_params: %{
        "gate2_request_applied" => true,
        "gate1_request_applied" => true,
        "step" => 2
      }
    } = context[:conn]
    |> insert_version_header(version)
    |> call(gates)
  end

  test "applies response gates", context do
    version = "2016-01-01"
    gates = init([gates: [
      "2016-03-01": MultiverseTest.GateSampleTwo,
      "2016-02-01": MultiverseTest.GateSampleOne
    ]])

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version},
      query_params: %{
        "gate2_request_applied" => true,
        "gate1_request_applied" => true,
        "gate2_response_applied" => true,
        "gate1_response_applied" => true,
        "step" => 4
      }
    } = context[:conn]
    |> insert_version_header(version)
    |> call(gates)
    |> send_resp(200, "body")
  end

  test "applies gates in correct order", context do
    # DESC order
    version = "2016-01-01"
    gates = init([gates: [
      "2016-03-01": MultiverseTest.GateSampleTwo,
      "2016-02-01": MultiverseTest.GateSampleOne
    ]])

    conn_desc = context[:conn]
    |> insert_version_header(version)
    |> call(gates)

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version},
      query_params: %{
        "step" => 2
      }
    } = conn_desc

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version},
      query_params: %{
        "step" => 4
      }
    } = conn_desc
    |> send_resp(200, "body")

    # ASC order
    gates = init([gates: [
      "2016-02-01": MultiverseTest.GateSampleOne,
      "2016-03-01": MultiverseTest.GateSampleTwo
    ]])

    conn_asc = context[:conn]
    |> insert_version_header(version)
    |> call(gates)

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version},
      query_params: %{
        "step" => 2
      }
    } = conn_asc

    assert %Plug.Conn{
      assigns: %{client_api_version: ^version},
      query_params: %{
        "step" => 4
      }
    } = conn_asc
    |> send_resp(200, "body")
  end

  test "doesn't affect newest clients", context do
    version = "2016-04-01"
    gates = init([gates: [
      "2016-02-01": MultiverseTest.GateSampleOne,
      "2016-03-01": MultiverseTest.GateSampleTwo
    ]])

    conn = context[:conn]
    |> insert_version_header(version)
    |> call(gates)
    |> send_resp(200, "body")

    assert %Plug.Conn{
      assigns: %{
        client_api_version: ^version,
        active_api_gates: []
      },
      query_params: query_params
    } = conn

    refute Map.has_key?(query_params, "step")
    refute Map.has_key?(query_params, "gate1_request_applied")
    refute Map.has_key?(query_params, "gate1_response_applied")
    refute Map.has_key?(query_params, "gate2_request_applied")
    refute Map.has_key?(query_params, "gate2_response_applied")
  end

  test "applies only newer versions", context do
    version = "2016-02-02"
    gates = init([gates: [
      "2016-02-01": MultiverseTest.GateSampleOne,
      "2016-03-01": MultiverseTest.GateSampleTwo
    ]])

    conn = context[:conn]
    |> insert_version_header(version)
    |> call(gates)

    assert %Plug.Conn{
      assigns: %{
        client_api_version: ^version,
      },
      query_params: %{
        "gate2_request_applied" => true,
        "step" => 2
      } = query_params
    } = conn

    refute Map.has_key?(query_params, "gate1_request_applied")
    refute Map.has_key?(query_params, "gate1_response_applied")

    assert %Plug.Conn{
      assigns: %{
        client_api_version: ^version,
      },
      query_params: %{
        "gate2_request_applied" => true,
        "gate2_response_applied" => true,
        "step" => 3
      } = query_params
    } = conn
    |> send_resp(200, "body")

    refute Map.has_key?(query_params, "gate1_request_applied")
    refute Map.has_key?(query_params, "gate1_response_applied")
  end

  defp insert_version_header(%Plug.Conn{req_headers: req_headers} = conn, version) do
    %Plug.Conn{conn | req_headers: [{@version_header, version} | req_headers]}
  end

  def custom_error_callback(_, _) do
    "custom_default_value"
  end
end
