defmodule MultiverseGate do
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
  Defines a request mutator.

  This function will be called whenever Cowboy receives request.
  """
  @callback mutate_request(Conn.t) :: Conn.t

  @doc """
  Defines a response mutator.

  This function will be called whenever Cowboy sends response to a consumer.
  """
  @callback mutate_response(Conn.t) :: Conn.t
end
