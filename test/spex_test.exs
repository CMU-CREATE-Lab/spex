defmodule SpexTest do
  use ExUnit.Case
  doctest Spex

  test "greets the world" do
    assert Spex.hello() == :world
  end
end
