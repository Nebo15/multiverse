defmodule Multiverse.Change do
  @moduledoc """
  Provides behaviour and macro to build Multiverse API Changes.
  """

  @doc false
  defmacro __using__(opts) do
    quote do
      import Multiverse.Change#, only: [mutate_endpoint: 3]
      require Multiverse.Change
      @behaviour Multiverse.Change

      @multiverse_change_opts unquote(opts)

      def handle_request(conn), do: do_handle_request(conn)
      def handle_response(conn), do: do_handle_response(conn)

      Module.register_attribute(__MODULE__, :mutations, accumulate: true)
      @before_compile Multiverse.Change
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    mutations = Module.get_attribute(env.module, :mutations)
    change_opts = Module.get_attribute(env.module, :multiverse_change_opts)

    {conn, request_mutations_body, response_mutations_body} = Multiverse.Change.compile(env, mutations, change_opts)

    quote do
      def do_handle_request(unquote(conn)), do: unquote(request_mutations_body)
      def do_handle_response(unquote(conn)), do: unquote(response_mutations_body)
    end
  end

  @doc """
  Checks if change is active on connection or version schema.
  """
  @spec active?(conn_or_version_schema :: Plug.Conn.t() | Multiverse.VersionSchema.t(), change :: module) :: boolean
  def active?(%Multiverse.VersionSchema{changes: changes}, change), do: change in changes

  def active?(%Plug.Conn{private: %{multiverse_version_schema: version_schema}}, change),
    do: active?(version_schema, change)

  @doc """
  Defines a request mutator.

  Request mutation is applied when when Multiverse plug is called.
  """
  @callback handle_request(conn :: Plug.Conn.t()) :: Plug.Conn.t()

  @doc """
  Defines a response mutator.

  Response mutation is applied via `Plug.Conn.register_before_send/2`.
  """
  @callback handle_response(conn :: Plug.Conn.t()) :: Plug.Conn.t()

  @doc """
  Applies change only if the request method and path are matched.

  ## Example

      defmodule ChangeAccountType do
        use Multiverse.Change

        mutate_endpoint :get, "templates/:id" do
          :request, conn ->
            # Mutate your request here
            IO.inspect "ChangeAccountType request mutated"
            conn

          :response, conn ->
            # Mutate your response here
            IO.inspect "ChangeAccountType response mutated"
            conn
        end
      end
  """
  defmacro mutate_endpoint(method_or_methods, expr, do: body) do
    methods = List.wrap(method_or_methods)
    {path, guards} = extract_path_and_guards(expr)
    changes = exctract_changes(body, __CALLER__)
    request_changes_body = List.keyfind(changes, :request, 0)
    response_changes_body = List.keyfind(changes, :response, 0)

    quote bind_quoted: [
            methods: methods,
            path: path,
            guards: Macro.escape(guards, unquote: true),
            request_changes_body: Macro.escape(request_changes_body, unquote: true),
            response_changes_body: Macro.escape(response_changes_body, unquote: true),
          ] do
      for method <- methods do
        @mutations {method, path, guards, request_changes_body, response_changes_body}
      end
    end
  end

  @doc false
  def compile(env, mutations, change_opts) do
    IO.inspect {env, mutations, change_opts}
    {nil, nil, nil}
    # quote bind_quoted: [
    #         method: method,
    #         path: path,
    #         guards: Macro.escape(guards, unquote: true),
    #         request_changes_body: Macro.escape(request_changes_body, unquote: true),
    #         response_changes_body: Macro.escape(response_changes_body, unquote: true),
    #       ] do
    #   route = Plug.Router.__route__(method, path, guards, [])
    #   {conn, method, match, params_match, host, guards, _private, _assigns} = route
    #   IO.inspect route

    #   if request_changes_body do
    #     {:request, conn_binding, change_body} = request_changes_body
    #     defp do_handle_request(unquote(conn_binding)), do: unquote(change_body)
    #   end

    #   if response_changes_body do
    #     {:response, conn_binding, change_body} = response_changes_body
    #     defp do_handle_response(unquote(conn_binding)), do: unquote(change_body)
    #   end

    #   # defp do_handle_request(unquote(conn), unquote(method), unquote(match), unquote(host))
    #   #      when unquote(guards) do

    #   #   merge_params = fn
    #   #     %Plug.Conn.Unfetched{} -> unquote({:%{}, [], params})
    #   #     fetched -> Map.merge(fetched, unquote({:%{}, [], params}))
    #   #   end

    #   #   conn = update_in(unquote(conn).params, merge_params)
    #   #   conn = update_in(conn.path_params, merge_params)

    #   #   Plug.Router.__put_route__(conn, unquote(path), fn var!(conn) -> unquote(body) end)
    #   # end
    # end
  end

  defp exctract_changes(body, caller, acc \\ [])

  defp exctract_changes([], _caller, acc) do
    acc
  end

  defp exctract_changes([{:->, ctx, [[kind, conn_binding], change_body]} | t], caller, acc)
    when kind in [:request, :response] do
    if List.keymember?(acc, kind, 0) do
      raise SyntaxError,
        file: caller.file,
        line: ctx[:line],
        description: "mutation for #{kind} is already defined"
    end

    exctract_changes(t, caller, acc ++ [{kind, conn_binding, change_body}])
  end

  defp exctract_changes([{:->, ctx, [[kind, _conn_binding], _change_body]} | _], caller, _acc) do
    raise SyntaxError,
      file: caller.file,
      line: ctx[:line],
      description: "unknown mutation kind #{kind}, supported kinds: :request, :response"
  end

  defp exctract_changes({:__block__, _ctx, []}, caller, _acc) do
    raise SyntaxError,
      file: caller.file,
      line: caller.line,
      description: "mutation can not be empty"
  end

  defp exctract_changes(_ast, caller, _acc) do
    description = "invalid syntax for endpoint mutation, for a valid syntax see Multiverse.Change.mutate_endpoint/3 doc"
    raise SyntaxError,
      file: caller.file,
      line: caller.line,
      description: description
  end

  # Extract the path and guards from the path.
  defp extract_path_and_guards({:when, _, [path, guards]}), do: {extract_path(path), guards}
  defp extract_path_and_guards(path), do: {extract_path(path), true}

  defp extract_path({:_, _, var}) when is_atom(var), do: "/*_path"
  defp extract_path(path), do: path
end
