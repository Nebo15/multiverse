defmodule Multiverse.Adapters.ISODate do
  @moduledoc """
  Adapter that fetches ISO-8601 date from request header and `Elixir.Date`
  to resolve changes that must be applied to the connection.

  Current date is used as fallback when:
    * version header is not present in request;
    * value of a version header is malformed (and warning is logged);
    * `latest` channel is used instead of date.

  When `edge` channel is used instead of date, no changes are applied to the connection.
  """
  require Logger

  @behaviour Multiverse.Adapter

  @typep version :: Date.t()

  def init(_adapter, opts), do: {:ok, opts}

  @spec version_comparator(v1 :: version, v2 :: version) :: boolean
  def version_comparator("edge", _v2), do: false
  def version_comparator(v1, v2), do: Date.compare(v1, v2) == :lt

  @spec fetch_default_version(conn :: Plug.Conn.t()) :: {:ok, version, Plug.Conn.t()}
  def fetch_default_version(conn), do: {:ok, Date.utc_today(), conn}

  @spec resolve_version_or_channel(conn :: Plug.Conn.t(), channel_or_version :: String.t()) :: {
          :ok,
          version,
          Plug.Conn.t()
        }
  def resolve_version_or_channel(conn, "latest") do
    fetch_default_version(conn)
  end

  def resolve_version_or_channel(conn, "edge") do
    {:ok, "edge", conn}
  end

  def resolve_version_or_channel(conn, version) do
    case Date.from_iso8601(version) do
      {:ok, date} ->
        {:ok, date, conn}

      {:error, reason} ->
        :ok = Logger.warn("Malformed version header: `#{inspect(reason)}`, failing back to the default version")
        fetch_default_version(conn)
    end
  end
end
