# Ersatz

[![version](https://img.shields.io/hexpm/v/ersatz.svg?label=hex&style=flat-square)](https://hex.pm/packages/ersatz)
![build master](https://img.shields.io/circleci/project/github/Apemb/ersatz/master.svg?label=build%20master&style=flat-square)

Ersatz is a library for defining mocks in Elixir.

**It is not guaranteed to be stable for the moment.**
**Contributions welcome :-)**

Ersatz in a fork of [Mox](https://github.com/plataformatec/mox) and follows mosts of principles outlined in ["Mocks and explicit contracts"](http://blog.plataformatec.com.br/2015/10/mocks-and-explicit-contracts/).

[But why a fork ?](WHY_A_FORK.md)
 
## Usage 

-   Mocks are generated based on behaviours during configuration and injected using env variables.
-   Add the mock behaviour by specifying functions to be used during tests with `Ersatz.set_mock_implementation/2`.
-   Test your code's actions on the mock dependency using `Ersatz.get_mock_calls/1` or the Espec custom matchers.

[See the documentation](https://hexdocs.pm/ersatz) for more information.

## Installation

Add `ersatz` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ersatz, "~> 0.1.1", only: :test}
  ]
end
```

## To Do

- [ ] clarify documentation
- [ ] function to clear all previous calls
- [ ] add custom assertions for ExUnit
- [ ] Test concurrency support. (should be ok, but... )
- [X] add configuration for initializing mocks before start of application under test

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
