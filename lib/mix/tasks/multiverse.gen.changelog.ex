defmodule Mix.Tasks.Multiverse.Gen.Changelog do
  use Mix.Task

  @shortdoc "Generates a changelog from changes @moduledoc's"

  @moduledoc """
  Generate a changelog from changes @moduledoc's.

  ## Changelog Generator

  Multiverse doesn't make assumptions on how do you want changelog to look like
  and where do you want it to write, instead you need to implement
  `Multiverse.ChangelogWriter` behaviour and set it in `:multiverse`
  application environment:

  ```
  config :multiverse,
    changelog_generator: MyApp.ChangelogWriter,
    endpoint: MyApp.Endpoint
  ```

  ## Examples

      mix multiverse.gen.changelog -e MyApp.Endpoint

  This generator will automatically open the config/config.exs
  after generation if you have `ECTO_EDITOR` set in your environment
  variable.

  ## Command line options

    * `-e`, `--endpoint` - the endpoint to inspect for effective changes;
    * `-i`, `--include-future-version` - include future versions that are not in effect right now (default `false`);
    * `-g`, `--generator` - the `Multiverse.ChangelogWriter` behaviour implementation to write the changelog.

  """

  @doc false
  def run(args) do

  end
end
