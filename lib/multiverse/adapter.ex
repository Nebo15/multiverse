defmodule Multiverse.Adapter do
  @moduledoc """
  This module provides behaviour for Multiverse adapters.
  """

  @type version :: any
  @type changes :: [module]
  @type gates :: [%{version => changes}]

  @doc """
  Initialize adapter configuration at compile time.

  This callback can be used to fetch Multiverse configuration
  from application environment, file or other places.
  """
  @callback init(adapter :: module, opts :: Keyword.t()) :: {:ok, Keyword.t()}

  @doc """
  Comparator that is used to order and filter versions that
  should be applied to a connection.

  It should compare two arguments, and return true if
  the first argument precedes the second one or they are equal.
  """
  @callback version_comparator(v1 :: version, v2 :: version) :: boolean

  @doc """
  Fetch default client version.

  This callback is used when version header is not set or empty.
  Additionally adapters may use it to fallback to default version
  in case of errors or when version header value is malformed.
  """
  @callback fetch_default_version(conn :: Plug.Conn.t()) :: {:ok, version, Plug.Conn.t()}

  @doc """
  Resolve version by string value from request header.

  This callback can be used to set named channels for API versions,
  for eg. `latest` header value could be resolved to current date and
  `edge` to the most recent defined version.

  Also, it is responsible for casting string value to adapter-specific
  version type and handling possible errors.

  You can terminate connection if you want to return error without
  further processing of the request.
  """
  @callback resolve_version_or_channel(conn :: Plug.Conn.t(), channel_name_or_version :: String.t()) :: {
              :ok,
              version,
              Plug.Conn.t()
            }

  @doc false
  # Resolves adapter configuration at compile time
  @spec compile_config!(adapter :: module, opts :: Keyword.t()) :: Keyword.t()
  def compile_config!(adapter, opts) do
    unless Code.ensure_loaded?(adapter) do
      raise ArgumentError,
            "adapter #{inspect(adapter)} was not compiled, " <>
              "ensure it is correct and it is included as a project dependency"
    end

    case adapter.init(adapter, opts) do
      {:ok, config} ->
        config

      error ->
        raise ArgumentError, """
        Can not initialize #{inspect(adapter)} Multiverse adapter.

        Adapter must implement `init/2` callback which
        returns `{:ok, config}` tuple.

        Returned value `#{inspect(error)}`
        """
    end
  end
end
