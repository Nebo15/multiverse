defmodule MultiverseGate do
  import Plug.Conn

  @doc "Defines request mutator"
  @callback mutate_request(Conn.t) :: Conn.t

  @doc "Defines response mutator"
  @callback mutate_response(Conn.t) :: Conn.t
end

defmodule Multiverse do
  @behaviour Plug
  @default_version_header "x-api-version"

  import Plug.Conn

  def init(opts) do
    %{
      gates: opts[:gates] || [],
      error_callback: opts[:error_callback] || {Multiverse, :default_error_callback},
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
    get_req_header(conn, version_header)
    |> List.first
    |> normalize_api_version(error_callback)
    |> (&assign(conn, :client_api_version, &1)).()
  end

  defp normalize_api_version(version, _) when is_nil(version) or version == "latest" do
    get_latest_version
  end

  defp normalize_api_version(version, {error_callback_module, error_callback_method}) do
    case Timex.parse(version, "{YYYY}-{0M}-{0D}") do
      {:error, reason} ->
        apply(error_callback_module, error_callback_method, [reason])
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
