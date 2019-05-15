# Ersatz

[![version](https://img.shields.io/hexpm/v/ersatz.svg?label=hex&style=flat-square)](https://hex.pm/packages/ersatz)
![build master](https://img.shields.io/circleci/project/github/Apemb/ersatz/master.svg?label=build%20master&style=flat-square)

Ersatz is a library for defining mocks in Elixir.

As a fork of Mox the library also follows some of principles outlined in ["Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/)
, summarized below:

  1. No ad-hoc mocks. You can only create mocks based on behaviours

  2. No dynamic generation of modules during tests. Mocks are preferably defined in your `test_helper.exs`
   or in a `setup_all` block and not per test

But the capacity to test the calls is not dependent on pattern matching (as in Mox for example), 
and should be tested as a result of explicit assertion.
 
  ?? 1. Concurrency support. Tests using the same mock can still use `async: true`

[See the documentation](https://hexdocs.pm/ersatz) for more information.

## Installation

Add `ersatz` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ersatz, "~> 0.1", only: :test}
  ]
end
```

## License

Ersatz is a fork of Plataformatec Mox library.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
