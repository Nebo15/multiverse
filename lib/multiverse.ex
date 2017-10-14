defmodule Multiverse do
  @moduledoc """
  This plug helps to manage multiple API versions based on request and response gateways.
  This is an awesome practice to hide your backward compatibility.
  It allows to have your code in a latest possible version, without duplicating controllers or models.

  For more information see [README.md](https://github.com/Nebo15/multiverse/).
  """
  @behaviour Plug

  defmodule VersionSchema do
    @moduledoc """
    This module defines schema that is assigned to `conn.private[:multiverse_version_schema]`
    and can be used by third-party libraries to store or process API version and changes data.

    ## Available attributes

    * `adapter` - adapter which were used to handle connection;
    * `version` - version which is assigned for consumer connection;
    * `changes` - ordered list of changes that were applied to the connection.
    """
    @type t :: %__MODULE__{adapter: module, version: any, changes: [module]}
    defstruct [:adapter, :version, :changes]
  end

  @default_version_header "x-api-version"
  @default_adapter Multiverse.Adapters.ISODate

  @doc """
  Initializes Multiverse plug.

  Raises at compile time when adapter or change is not loaded.

  Available options:
    * `:adapter` - module which implements `Multiverse.Adapter` behaviour;
    * `:version_header` - header which is used to fetch consumer version;
    * `:gates` - list of gates (and changes) that are available for consumers.
  """
  @spec init(Keyword.t) :: Map.t
  def init(opts) do
    endpoint = Keyword.get(opts, :endpoint)
    opts =
      if endpoint do
        Keyword.merge(opts, Application.get_env(:multiverse, endpoint, []))
      else
        opts
      end

    adapter = Keyword.get(opts, :adapter, @default_adapter)
    config = Multiverse.Adapter.compile_config!(adapter, opts)
    version_header = Keyword.get(opts, :version_header, @default_version_header)
    gates =
      config
      |> Keyword.get(:gates, [])
      |> enshure_changes_loaded!()
      |> sort_gates(adapter)

    %{adapter: adapter, version_header: version_header, gates: gates}
  end

  defp enshure_changes_loaded!(gates) do
    # credo:disable-for-lines:3
    Enum.map(gates, fn {_version, changes} ->
      Enum.map(changes, &enshure_change_loaded/1)
    end)

    gates
  end

  defp enshure_change_loaded(change_mod) do
    unless Code.ensure_loaded?(change_mod) do
      raise ArgumentError, "change module #{inspect change_mod} was not compiled, " <>
                           "ensure it is correct and it is included as a project dependency"
    end
  end

  defp sort_gates(gates, adapter) do
    gates
    |> Enum.sort_by(fn {gate_version, _gate_changes} -> gate_version end, &adapter.version_comparator/2)
    |> Enum.into(%{})
  end

  @spec call(conn :: Plug.Conn.t, opts :: Map.t) :: Plug.Conn.t
  def call(conn, opts) do
    %{adapter: adapter, version_header: version_header, gates: gates} = opts
    {:ok, consumer_api_version, conn} = fetch_consumer_api_version(adapter, conn, version_header)
    version_changes = changes_for_version(adapter, consumer_api_version, gates)
    version_schema =
      %Multiverse.VersionSchema{
        adapter: adapter,
        version: consumer_api_version,
        changes: version_changes
      }

    conn
    |> apply_request_changes(version_schema)
    |> apply_response_changes(version_schema)
    |> Plug.Conn.put_private(:multiverse_version_schema, version_schema)
  end

  defp fetch_consumer_api_version(adapter, conn, version_header) do
    case Plug.Conn.get_req_header(conn, version_header) do
      [] -> adapter.fetch_default_version(conn)
      ["" | _] -> adapter.fetch_default_version(conn)
      [version_or_channel | _] -> adapter.resolve_version_or_channel(conn, version_or_channel)
    end
  end

  defp changes_for_version(adapter, consumer_version, gates) do
    Enum.reduce(gates, [], fn {gate_version, gate_changes}, changes ->
      if adapter.version_comparator(consumer_version, gate_version) do
        changes ++ gate_changes
      else
        changes
      end
    end)
  end

  defp apply_request_changes(conn, %{changes: []}),
    do: conn
  defp apply_request_changes(conn, %{changes: changes}) do
    Enum.reduce(changes, conn, fn change_mod, conn ->
      change_mod.handle_request(conn)
    end)
  end

  defp apply_response_changes(conn, %{changes: []}),
    do: conn
  defp apply_response_changes(conn, %{changes: changes}) do
    Enum.reduce(changes, conn, fn change_mod, conn ->
      Plug.Conn.register_before_send(conn, fn conn ->
        change_mod.handle_response(conn)
      end)
    end)
  end
end
