# Multiverse

[![Deps Status](https://beta.hexfaktor.org/badge/all/github/Nebo15/multiverse.svg)](https://beta.hexfaktor.org/github/Nebo15/multiverse) [![Hex.pm Downloads](https://img.shields.io/hexpm/dw/multiverse.svg?maxAge=3600)](https://hex.pm/packages/multiverse) [![Latest Version](https://img.shields.io/hexpm/v/multiverse.svg?maxAge=3600)](https://hex.pm/packages/multiverse) [![License](https://img.shields.io/hexpm/l/multiverse.svg?maxAge=3600)](https://hex.pm/packages/multiverse) [![Build Status](https://travis-ci.org/Nebo15/multiverse.svg?branch=master)](https://travis-ci.org/Nebo15/multiverse) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/multiverse/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/multiverse?branch=master) [![Ebert](https://ebertapp.io/github/Nebo15/multiverse.svg)](https://ebertapp.io/github/Nebo15/multiverse)

This plug helps to manage multiple API versions based on request and response gateways. This is an awesome practice to hide your backward compatibility. It allows to have your code in a latest possible version, without duplicating controllers or models.

Best practice is to store consumer version upon his first request and add a ```error_handler``` that will load if from a storage, and set it for user automatically. So, basically, they won't need to know which version they are using, until they will explicitly set it via request header.

![Compatibility Layers](http://amberonrails.com/images/posts/move-fast-dont-break-your-api/compatibility-layers.png "Compatibility Layers")

Inspired by Stripe API. Read more at [MOVE FAST, DON'T BREAK YOUR API](http://amberonrails.com/move-fast-dont-break-your-api/).

## Installation

The package (take look at [hex.pm](https://hex.pm/packages/multiverse)) can be installed as:

  1. Add `multiverse` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:multiverse, "~> 0.4.2"}]
    end
    ```

  2. Make sure that `multiverse` is available at runtime in your production:

    ```elixir
    def application do
      [applications: [:multiverse]]
    end
    ```

## How to use

  1. Insert this plug into your API pipeline (```router.ex```):

    ```elixir
    pipeline :api do
      plug :accepts, ["json"]
      plug :put_secure_browser_headers
      plug Multiverse
    end
    ```

  2. Create your first API gateway

    ```elixir
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
    ```

  3. Attach gate to multiverse:

    ```elixir
    pipeline :api do
      plug :accepts, ["json"]
      plug :put_secure_browser_headers
      plug Multiverse, gates: [
        "2016-07-31": GateName
      ]
    end
    ```

  ***Notice:*** your API versions should be strings in YYYY-MM-DD format to be appropriately compared to current version.

  4. Send your API requests with ```X-API-Version``` header with version lower than ```2016-07-31```.

## Custom version header

  You can use any version headers by passing option to Multiverse:

    ```elixir
    pipeline :api do
      plug :accepts, ["json"]
      plug :put_secure_browser_headers
      plug Multiverse, gates: [
        "2016-07-31": GateName
      ], version_header: "X-My-API-Version"
    end
    ```

## Custom error handlers

  Sometimes clients are sending corrupted version headers, by default Multiverse will fallback to "latest" version. But you can set your own handler for this situations:

    ```elixir
    pipeline :api do
      plug :accepts, ["json"]
      plug :put_secure_browser_headers
      plug Multiverse, gates: [
        "2016-07-31": GateName
      ], error_callback: &IO.inspect/1
    end
    ```

  Custom error callback should be a function that returns string:

    ```elixir
    def custom_error_callback(%Plug.Conn{} = _conn, reason) do
      IO.inspect reason
      "2015-01-03"
    end
    ```

## Structuring your tests

  1. Split your tests into versions:

    ```bash
    $ ls -l test/acceptance
    total 0
    drwxr-xr-x  2 andrew  staff  68 Aug  1 19:23 GateName
    drwxr-xr-x  2 andrew  staff  68 Aug  1 19:24 OlderGateName
    ```

  2. Avoid touching request or response in old tests. Create API gates and matching folder in acceptance tests.
