defmodule Multiverse.Change do
  @moduledoc """
  Provides behaviour for Multiverse API Changes.

  ## Examples

      defmodule ChangeAccountType do
        @behaviour Multiverse.Change

        def handle_request(%Plug.Conn{} = conn) do
          # Mutate your request here
          IO.inspect "GateName.mutate_request applied to request"
          conn
        end

        def handle_response(%Plug.Conn{} = conn) do
          # Mutate your response here
          IO.inspect "GateName.mutate_response applied to response"
          conn
        end
      end

  """

  @doc """
  Macros that can be used if you want to omit either `handle_request/1`
  or `handle_response/1` callback in your change module.
  """
  defmacro __unsing__(_opts) do
    quote do
      @behaviour Multiverse.Change

      def handle_request(conn),
        do: conn

      def handle_response(conn),
        do: conn

      defoverridable [handle_request: 1, handle_response: 1]
    end
  end

  @doc """
  Checks if change is active on connection or version schema.
  """
  @spec active?(conn_or_version_schema :: Plug.Conn.t | Multiverse.VersionSchema.t, change :: module) :: boolean
  def active?(%Multiverse.VersionSchema{changes: changes}, change),
    do: change in changes
  def active?(%Plug.Conn{private: %{multiverse_version_schema: version_schema}}, change),
    do: active?(version_schema, change)

  @doc """
  Defines a request mutator.

  This function will be called whenever Cowboy receives request.
  """
  @callback handle_request(conn :: Plug.Conn.t) :: Plug.Conn.t

  @doc """
  Defines a response mutator.

  This function will be called before Cowboy is dispatched response to a consumer.
  """
  @callback handle_response(conn :: Plug.Conn.t) :: Plug.Conn.t
end
