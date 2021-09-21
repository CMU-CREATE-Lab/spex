defmodule SpexTest do
  use ExUnit.Case
  doctest Spex

  test "greets the world" do
    assert Spex.hello() == :world
  end

  # test "convolve 1" do
  #   conv = Spex.Convolve.convolve(
  #     Nx.tensor([0, 1, 2, 3]),
  #     Nx.tensor([0, 1, 1, 0]),
  #     Nx.tensor([-0.75, -0.25, 0.25, 0.75]),
  #     Nx.tensor([0, 0.5, 0.5, 0])
  #   )
  #   assert conv == [Nx.tensor(0.03515625), Nx.tensor(0.15234375), Nx.tensor(0.15234375), Nx.tensor(0.03515625)]
  # end

  # test "convolve 2" do
  #   conv = Spex.Convolve.convolve(
  #     Nx.tensor([0, 1, 2, 3]),
  #     Nx.tensor([1, 1, 1, 1]),
  #     Nx.tensor([-1.0, 0.0, 1.0]),
  #     Nx.tensor([0, 1.0, 0])
  #   )
  #   assert conv == [Nx.tensor(1.0), Nx.tensor(1.0), Nx.tensor(1.0), Nx.tensor(1.0)]
  # end

  # test "convolve 3" do
  #   conv = Spex.Convolve.convolve(
  #     Nx.tensor([0, 1, 2, 3]),
  #     Nx.tensor([1, 1, 1, 1]),
  #     Nx.tensor([-0.5, 0.0, 0.5]),
  #     Nx.tensor([0, 2.0, 0])
  #   )
  #   assert conv == [Nx.tensor(1.0), Nx.tensor(1.0), Nx.tensor(1.0), Nx.tensor(1.0)]
  # end

  import ExUnit.CaptureIO

  test "sequence 1" do
    result = capture_io(fn ->
      conv = Spex.Convolve.convolve(
        Nx.tensor([0, 1, 2, 3]),
        Nx.tensor([1, 1, 1, 1]),
        Nx.tensor([-0.5, 0.0, 0.5]),
        Nx.tensor([0, 2.0, 0])
      )
      IO.puts("#{inspect(conv)}")
    end)

    assert result == [Nx.tensor(1.0), Nx.tensor(1.0), Nx.tensor(1.0), Nx.tensor(1.0)]
  end

end
