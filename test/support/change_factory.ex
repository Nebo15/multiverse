defmodule ChangeFactory do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @behaviour Multiverse.Change

      def handle_request(%Plug.Conn{assigns: assigns} = conn) do
        applied_changes = Map.get(assigns, :applied_changes, []) ++ [:"#{__MODULE__}.handle_request"]
        %{conn | assigns: Map.put(assigns, :applied_changes, applied_changes)}
      end

      def handle_response(%Plug.Conn{assigns: assigns} = conn) do
        applied_changes = Map.get(assigns, :applied_changes, []) ++ [:"#{__MODULE__}.handle_response"]
        %{conn | assigns: Map.put(assigns, :applied_changes, applied_changes)}
      end
    end
  end
end
