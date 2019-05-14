# ErsatzExample

## Description

This example is a barebones example of how to use [Ersatz](https://github.com/apemb/ersatz) and how to configure it during testing.

## How

Run `mix test` and you'll see a mocked HTTP call tested without making the HTTP call.

Run `iex -S mix` and then `ErsatzExample.post_name("Ersatz")` and you'll see the HTTP request go through!
