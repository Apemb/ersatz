# Why a fork ? 

Mox is a brillant piece of software. I liked very much the possibility of being obliged to define dependencies as
behaviour and that `Mox` could infer a mock module from that behaviour.

But on the other hand, I am used to write tests in three steps: 
 1. Given => write the context in which the code you work on will act
 2. When => the specific action you test
 3. Then => the assertions to valid the code actually behaved as you planned.  

My feeling on `Mox` is that you have mix phase 1 & 3 in the same line of code. 

```elixir
# With Mox
# Taken from Mox example app

test "posts name" do
  name = "Jim"

  ## Here you are setting context and behaviour expectations
  ExampleAPIMock
  |> expect(:api_post, fn ^name, [], [] -> {:ok, nil} end)

  assert MoxExample.post_name(name) == {:ok, nil}
end
```

When you add the expectation with pattern matching, in the same line you set the context on your code 
(the api mock will return `{:ok, nil}`) and the expectation that your code will behave in a way it will give the 
api module the name as first argument. One line, two actions. 

```elixir
# With Ersatz

test "posts name" do
  name = "Jim"
  Ersatz.set_mock_implementation(&ExampleAPIMock.api_post/3, fn _, _, _ -> {:ok, nil} end)

  response = MoxExample.post_name(name)

  calls = Ersatz.get_mock_calls(&ExampleAPIMock.api_post/3)
  assert calls == [{^name, [], []}]

  assert response == {:ok, nil}
end
```

With Ersatz the line where one sets the behaviour of the context in which the tested code lives is on the 
` Ersatz.set_mock_implementation` line. And the test code behaviour validation is done, if need be, with `Ersatz.get_mock_calls`
the validate what your code actually called the mock implementation with. 

(if you use `Espec` you would have a more fluent way to do that using `have_been_called` and `have_been_called_with`)
  
```elixir
# With Ersatz and Espec

it "posts name" do
  name = "Jim"
  Ersatz.set_mock_implementation(&ExampleAPIMock.api_post/3, fn _, _, _ -> {:ok, nil} end)

  response = MoxExample.post_name(name)

  (&ExampleAPIMock.api_post/3)
  |> should(have_been_called_with(exactly: [{^name, [], []}]))
  
  response
  |> should(equal {:ok, nil})
end
``` 
 