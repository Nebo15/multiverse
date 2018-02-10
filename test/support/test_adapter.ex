defmodule Multiverse.TestAdapter do
  @moduledoc false
  @behaviour Multiverse.Adapter

  def init(_adapter, opts), do: {:ok, Keyword.put(opts, :version_header, "test-adapter-version-header")}

  def version_comparator(_v1, _v2), do: raise "not implemented"

  def fetch_default_version(_conn), do: raise "not implemented"

  def resolve_version_or_channel(_conn, _version), do: raise "not implemented"
end
