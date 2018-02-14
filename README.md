# Multiverse

[![Deps Status](https://beta.hexfaktor.org/badge/all/github/Nebo15/multiverse.svg)](https://beta.hexfaktor.org/github/Nebo15/multiverse) [![Hex.pm Downloads](https://img.shields.io/hexpm/dw/multiverse.svg?maxAge=3600)](https://hex.pm/packages/multiverse) [![Latest Version](https://img.shields.io/hexpm/v/multiverse.svg?maxAge=3600)](https://hex.pm/packages/multiverse) [![License](https://img.shields.io/hexpm/l/multiverse.svg?maxAge=3600)](https://hex.pm/packages/multiverse) [![Build Status](https://travis-ci.org/Nebo15/multiverse.svg?branch=master)](https://travis-ci.org/Nebo15/multiverse) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/multiverse/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/multiverse?branch=master) [![Ebert](https://ebertapp.io/github/Nebo15/multiverse.svg)](https://ebertapp.io/github/Nebo15/multiverse)

This plug helps to manage multiple API versions based on request and response gateways. This is an awesome practice to hide your backward compatibility. It allows to have your code in a latest possible version, without duplicating controllers or models. We use it in production.

![Compatibility Layers](http://amberonrails.com/images/posts/move-fast-dont-break-your-api/compatibility-layers.png "Compatibility Layers")

Inspired by Stripe API. Read more at [MOVE FAST, DON'T BREAK YOUR API](http://amberonrails.com/move-fast-dont-break-your-api/) or [API versioning](https://stripe.com/blog/api-versioning).

## Goals

  - reduce changes required to support multiple API versions;
  - provide a way to test and schedule API version releases;
  - to have minimum dependencies and low performance hit;
  - to be flexible enough for most of projects to adopt it.

## Adapters

Multiverse allows you to use a custom adapter which can, for eg.:

  - store consumer version upon his first request and re-use it as default each time consumer is using your API, eliminating need of passing version headers for them (a.k.a. version pinning). Change this version when consumer has explicitly set it;
  - use _other than ISO date_ version types, eg. incremental counters (`v1`, `v2`);
  - handle malformed versions by responding with JSON errors.

Default adapter works with ISO-8601 date from `x-api-version` header (configurable). For malformed versions it would log a warning and fallback to the default date (configured via `:default_version` setting).

Also, it allows to use channel name instead of date, where:

  - `latest` channel would fallback to the current date;
  - `edge` channel would disable all changes altogether.

Channels allow you to plan version releases upfront and test them without affecting users,
just set future date for a change and pass it explicitly or use `edge` channel to test latest
application version.

## Installation

The package (take look at [hex.pm](https://hex.pm/packages/multiverse)) can be installed as:

  1. Add `multiverse` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:multiverse, "~> 2.0.0"}]
  end
  ```

  2. Make sure that `multiverse` is available at runtime in your production:

  ```elixir
  def application do
    [applications: [:multiverse]]
  end
  ```

## How to use

  1. Insert this plug into your API pipeline (in your ```router.ex```):

  ```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers

    plug Multiverse, default_version: :latest
  end
  ```

  2. Define module that handles change

  ```elixir
  defmodule AccountTypeChange do
    @behaviour Multiverse.Change

    def handle_request(%Plug.Conn{} = conn) do
      # Mutate your request here
      IO.inspect "AccountTypeChange.handle_request applied to request"
      conn
    end

    def handle_response(%Plug.Conn{} = conn) do
      # Mutate your response here
      IO.inspect "AccountTypeChange.handle_response applied to response"
      conn
    end
  end
  ```

  3. Enable the change:

  ```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers

    plug Multiverse,
      default_version: :latest,
      gates: %{
        ~D[2016-07-21] => [AccountTypeChange]
      }
  end
  ```

  4. Send your API requests with ```X-API-Version``` header with version lower or equal to ```2016-07-20```.

### Overriding version header

  You can use any version headers by passing option to Multiverse:

  ```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers

    plug Multiverse,
      default_version: :latest,
      version_header: "x-my-version-header",
      gates: %{
        ~D[2016-07-21] => [AccountTypeChange]
      }
  end
  ```

### Using custom adapters

  You can use your own adapter which implements `Multiverse.Adapter` behaviour:

  ```elixir
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers

    plug Multiverse,
      default_version: :latest,
      adapter: MyApp.SmartMultiverseAdapter,
      gates: %{
        ~D[2016-07-21] => [AccountTypeChange]
      }
  end
  ```

## Structuring your tests

  1. Split your tests into versions:

    $ ls -l test/acceptance
    total 0
    drwxr-xr-x  2 andrew  staff  68 Aug  1 19:23 AccountTypeChange
    drwxr-xr-x  2 andrew  staff  68 Aug  1 19:24 OlderChange

  2. Avoid touching request or response in old tests. Create API gates and matching folder in acceptance tests.

## Other things you might want to do

1. Store Multiverse configuration in `config.ex`:

  ```elixir
  use Mix.Config

  config :multiverse, MyApp.Endpoint,
    default_version: :latest,
    gates: %{
      ~D[2016-07-21] => [AccountTypeChange]
    }
  ```

  ```elixir
  plug Multiverse, endpoint: __MODULE__
  ```

2. Generate API documentation from changes `@moduledoc`'s.

3. Other awesome stuff. Open an issue and tell me about it! :).

# License

See [LICENSE.md](LICENSE.md).
