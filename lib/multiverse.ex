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

  import Plug.Conn

  defmodule Settings do
    @moduledoc """
      This is a struct that saves Multiverse options.
    """
    @type gates :: [{String.t(), MultiverseGate}]
    @type error_callback :: Fun
    @type version_header :: String.t()

    @type t :: %__MODULE__{
                gates: gates,
                error_callback: error_callback,
                version_header: version_header}

    defstruct gates: [],
              error_callback: &Multiverse.default_error_callback/2,
              version_header: "x-api-version"
  end

  @type opts :: [
            gates: Settings.gates,
            error_callback: Settings.error_callback,
            version_header: Settings.version_header]

  @spec init(opts) :: Settings.t
  def init(opts) do
    %Settings{
      gates: opts[:gates],
      error_callback: opts[:error_callback],
      version_header: opts[:version_header]
    }
    |> Map.merge(%Settings{}, fn (_k, curv, defv) -> curv || defv end)
  end

  @spec call(Conn.t, Settings.t) :: Conn.t
  def call(conn, %Settings{gates: [], error_callback: error_callback, version_header: version_header}) do
    conn
    |> assign_client_version(version_header, error_callback)
  end

  def call(conn, %Settings{gates: gates, error_callback: error_callback, version_header: version_header}) do
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
    |> normalize_api_version(error_callback, conn)
    |> (&assign(conn, :client_api_version, &1)).()
  end

  defp normalize_api_version(version, _, _) when is_nil(version) or version == "latest" do
    get_latest_version
  end

  defp normalize_api_version(version, error_callback, %Plug.Conn{} = conn) when is_function(error_callback) do
    case Timex.parse(version, "{YYYY}-{0M}-{0D}") do
      {:error, reason} ->
        error_callback.(conn, reason)
      {:ok, date} ->
        date
        |> Timex.format("{YYYY}-{0M}-{0D}")
        |> elem(1)
    end
  end

  def default_error_callback(_, _) do
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
