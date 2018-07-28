defmodule Multiverse.MyChange do
  use Multiverse.Change

  # def handle_request(conn), do: do_handle_request(conn)
  # def handle_response(conn), do: do_handle_response(conn)

  mutate_endpoint :get, "templates/:id" do
    :request, conn ->
      applied_changes = Map.get(conn.assigns, :applied_changes, []) ++ [:"#{__MODULE__}.handle_request1"]
      %{conn | assigns: Map.put(conn.assigns, :applied_changes, applied_changes)}

    :response, conn ->
      applied_changes = Map.get(conn.assigns, :applied_changes, []) ++ [:"#{__MODULE__}.handle_response1"]
      %{conn | assigns: Map.put(conn.assigns, :applied_changes, applied_changes)}
  end

  mutate_endpoint :get, "templates/:id" do
    :request, conn ->
      applied_changes = Map.get(conn.assigns, :applied_changes, []) ++ [:"#{__MODULE__}.handle_request2"]
      %{conn | assigns: Map.put(conn.assigns, :applied_changes, applied_changes)}

    :response, conn ->
      applied_changes = Map.get(conn.assigns, :applied_changes, []) ++ [:"#{__MODULE__}.handle_response2"]
      %{conn | assigns: Map.put(conn.assigns, :applied_changes, applied_changes)}
  end
end

defmodule Multiverse.ChangeTest do
  use ExUnit.Case, async: true
  use Plug.Test
  import Multiverse.Change
  doctest Multiverse.Change

  setup do
    %{conn: conn(:get, "/foo")}
  end

  describe "mutate_endpoint/3" do
    # test "applies changes", %{conn: conn} do
    #   config =
    #     Multiverse.init(
    #       default_version: :latest,
    #       gates: [
    #         {~D[2002-03-01], [Multiverse.MyChange]},
    #       ]
    #     )

    #   conn = %{conn | req_headers: [{"x-api-version", "2001-01-01"}]}

    #   conn =
    #     conn
    #     |> Multiverse.call(config)
    #     |> send_resp(204, "")

    #   assert length(conn.private.multiverse_version_schema.changes) == 2
    #   assert active?(conn, Multiverse.MyChange)

    #   assert conn.assigns.applied_changes ==
    #            [
    #              :"Elixir.Multiverse.MyChange.handle_request1",
    #              :"Elixir.Multiverse.MyChange.handle_request2",
    #              :"Elixir.Multiverse.MyChange.handle_response2",
    #              :"Elixir.Multiverse.MyChange.handle_response1"
    #            ]

    #   assert length(conn.before_send) == 2
    # end

    test "raises on duplicate mutation" do

    end

    test "raises on invalid mutation kind" do

    end

    test "raises on invalid mutation arithy" do

    end
  end
end
