defmodule Multiverse.Adapters.ISODate do
  @moduledoc """
  Adapter that fetches ISO-8601 date from request header and `Elixir.Date`
  to resolve changes that must be applied to the connection.

  This adapter requires you to configure which version is used by default,
  when value in a header was malformed or not set. It's configured via `:default_version`,
  supported values:

    * `:first` - apply all gates by default. This option is useful when you integrate Multiverse in existing project \
    and API consumers are not ready to accept latest changes by default;
    * `:latest` - user current date as default version. This option is useful when there are
    no legacy clients or there was no breaking changes before those clients started to send API version.

  ## Version Channels

  Consumers can use two channels instead of date in version header:

   * `latest` - apply only changes scheduled for future (with a date later than date when request arrived);
   * `edge` - do not apply any changes.
  """
  require Logger
  @behaviour Multiverse.Adapter

  @default_version_values [:latest, :oldest]

  @typep version :: Date.t()

  @doc """
  Initializes adapter configuration at compile time.

  Raises when `:default_version` option is not set.
  """
  def init(_adapter, opts) do
    default_version = Keyword.get(opts, :default_version)

    unless default_version do
      raise ArgumentError, "Multiverse.Adapters.ISODate :default_version config is not set"
    end

    unless default_version in @default_version_values do
      default_version_values_strings = Enum.map(@default_version_values, &inspect/1)

      raise ArgumentError,
            "invalid Multiverse.Adapters.ISODate :default_version config value, " <>
              "possible values: #{Enum.join(default_version_values_strings, ", ")}, " <>
              "got: #{inspect(default_version)}"
    end

    {:ok, opts}
  end

  @spec version_comparator(v1 :: version(), v2 :: version()) :: boolean
  def version_comparator("edge", _v2), do: false
  def version_comparator(v1, v2), do: Date.compare(v1, v2) == :lt

  @spec fetch_default_version(conn :: Plug.Conn.t(), adapter_config :: Multiverse.Adapter.config()) ::
          {:ok, version, Plug.Conn.t()}
  def fetch_default_version(conn, adapter_config) do
    case Keyword.get(adapter_config, :default_version) do
      :latest -> {:ok, Date.utc_today(), conn}
      :oldest -> {:ok, fetch_oldest_version(adapter_config), conn}
    end
  end

  defp fetch_oldest_version(adapter_config) do
    with gates when length(gates) > 0 <- Keyword.fetch!(adapter_config, :gates) do
      gates |> List.last() |> elem(0) |> Date.add(-1)
    else
      [] ->
        :ok =
          Logger.warn(fn ->
            "[Multiverse] You specified default_version: :oldest but there are no gates, failing back to the current date"
          end)

        Date.utc_today()
    end
  end

  @spec resolve_version_or_channel(
          conn :: Plug.Conn.t(),
          channel_or_version :: String.t(),
          adapter_config :: Multiverse.Adapter.config()
        ) :: {:ok, version, Plug.Conn.t()}
  def resolve_version_or_channel(conn, "latest", _adapter_config) do
    {:ok, Date.utc_today(), conn}
  end

  def resolve_version_or_channel(conn, "edge", _adapter_config) do
    {:ok, "edge", conn}
  end

  def resolve_version_or_channel(conn, version, adapter_config) do
    case Date.from_iso8601(version) do
      {:ok, date} ->
        {:ok, date, conn}

      {:error, reason} ->
        :ok =
          Logger.warn(fn ->
            "[Multiverse] Malformed version header: #{inspect(reason)}, failing back to the default version"
          end)

        fetch_default_version(conn, adapter_config)
    end
  end
end
