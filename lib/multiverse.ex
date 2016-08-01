defmodule MultiverseGate do
  import Plug.Conn

  @moduledoc """
  Provides behaviour for Multiverse API Gateways.

  ## Examples

      defmodule GateName do
        @behaviour MultiverseGate

        def mutate_request(%Plug.Conn{} = conn) do
          # Mutate your request here
          IO.inspect "GateName.mutate_request applied to request"
          conn
        end

        def mutate_response(%Plug.Conn{} = conn) do
          # Mutate your response here
          IO.inspect "GateName.mutate_response applied to response"
          conn
        end
      end

  """

  @doc """
  Defines a request mutator. It accepts %Plug.Conn{} and should return it.

  This function will be called whenever Cowboy receives request.
  """
  @callback mutate_request(Conn.t) :: Conn.t

  @doc """
  Defines a response mutator. It accepts %Plug.Conn{} and should return it.

  This function will be called whenever Cowboy sends response to a consumer.
  """
  @callback mutate_response(Conn.t) :: Conn.t
end

defmodule Multiverse do
  @moduledoc """
  This is a Plug that allows to manage multiple API versions on request/response gateways.

  ## Examples

      pipeline :api do
        ...
        plug Multiverse, gates: [
          "2016-07-31": GateName
        ], version_header: "x-api-version", error_callback: &custom_error_callback/1
      end

  """

  @behaviour Plug
  @default_version_header "x-api-version"

  import Plug.Conn

  def init(opts) do
    %{
      gates: opts[:gates] || [],
      error_callback: opts[:error_callback] || &default_error_callback/1,
      version_header: opts[:version_header] || @default_version_header
    }
  end

  def call(conn, %{gates: [], error_callback: error_callback, version_header: version_header}) do
    conn
    |> assign_client_version(version_header, error_callback)
  end

  def call(conn, %{gates: gates, error_callback: error_callback, version_header: version_header}) do
    conn
    |> assign_client_version(version_header, error_callback)
    |> assign_active_gates(gates)
    |> apply_request_gates
    |> apply_response_gates
  end

  defp assign_client_version(%Plug.Conn{} = conn, version_header, error_callback) do
    conn
    |> get_req_header(version_header)
    |> List.first
    |> normalize_api_version(error_callback)
    |> (&assign(conn, :client_api_version, &1)).()
  end

  defp normalize_api_version(version, _) when is_nil(version) or version == "latest" do
    get_latest_version
  end

  defp normalize_api_version(version, error_callback) when is_function(error_callback) do
    case Timex.parse(version, "{YYYY}-{0M}-{0D}") do
      {:error, reason} ->
        error_callback.(reason)
      {:ok, date} ->
        date
        |> Timex.format("{YYYY}-{0M}-{0D}")
        |> elem(1)
    end
  end

  def default_error_callback(_) do
    get_latest_version
  end

  defp get_latest_version do
    Timex.today
    |> Timex.format("{YYYY}-{0M}-{0D}")
    |> elem(1)
  end

  defp assign_active_gates(%Plug.Conn{assigns: %{client_api_version: version}} = conn, gates) do
    gates
    |> Enum.filter(&version_comparator(&1, version))
    |> (&assign(conn, :active_api_gates, &1)).()
  end

  # TODO: allow to pass any version comparator to a plug
  defp version_comparator({gate_version, _}, api_version) do
    Atom.to_string(gate_version) > api_version
  end

  defp apply_request_gates(%Plug.Conn{assigns: %{active_api_gates: gates}} = conn) do
    gates
    |> List.keysort(0)
    |> Enum.reduce(conn, &apply_request_gate(&1, &2))
  end

  defp apply_request_gate({_, gate_controller}, %Plug.Conn{} = conn) do
    apply(gate_controller, :mutate_request, [conn])
  end

  defp apply_response_gates(%Plug.Conn{assigns: %{active_api_gates: gates}} = conn) do
    gates
    |> List.keysort(1)
    |> Enum.reduce(conn, &apply_response_gate(&1, &2))
  end

  defp apply_response_gate({_, gate_controller}, %Plug.Conn{} = conn) do
    register_before_send(conn, &response_callback(&1, gate_controller))
  end

  defp response_callback(%Plug.Conn{} = conn, gate_controller) do
    apply(gate_controller, :mutate_response, [conn])
  end
end
