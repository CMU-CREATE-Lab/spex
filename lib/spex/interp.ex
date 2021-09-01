defmodule Spex.Interp do
  @moduledoc """
  Interpolate data.
  """

  # import Nx.Defn
  # @defn_compiler EXLA

  @doc """
  Search in a list/array for data (only really useful for arrays like `Nx.Tensor`) to stay O(log n).
  """
  def binsearch_pred(data, fun) do
    {len} = Nx.shape(data)
    binsearch_pred(data, fun, 0, len)
  end

  def binsearch_pred(data, fun, lo, hi) do
    # Logger.debug("lo #{inspect(lo)}, hi #{inspect(hi)}")
    cond do
      hi < lo ->
        -1

      hi == lo ->
        lo

      true ->
        mid = div(lo + hi, 2)
        pred = fun.(data[mid])
        # Logger.debug("lo #{Nx.to_scalar(lo)}, hi #{Nx.to_scalar(hi)}, pred #{inspect(pred)}")
        if !pred do
          binsearch_pred(data, fun, mid + 1, hi)
        else
          binsearch_pred(data, fun, lo, mid)
        end
    end
  end

  defp interp_pair(_x, i_prev, i_prev, _xdata, ydata) do
    ydata[i_prev]
  end

  defp interp_pair(x, i_prev, i_next, xdata, ydata) do
    {x_prev, x_next} = {xdata[i_prev], xdata[i_next]}
    sx = Nx.subtract(x_next, x_prev)
    dx = Nx.subtract(x, x_prev)
    u = Nx.divide(dx, sx)
    u1 = Nx.subtract(1.0, u)
    Nx.add(Nx.multiply(ydata[i_prev], u1), Nx.multiply(ydata[i_next], u))
  end

  @doc """
  Interpolate data linearly. `xdata` must be monotonically increasing
  """
  def interp(x, xdata, ydata, opts \\ []) do
    {len} = Nx.shape(xdata)
    ix_next = binsearch_pred(xdata, fn v -> Nx.to_scalar(v) > x end)
    ix_prev = max(ix_next - 1, 0)
    ix_next = min(ix_next, len - 1)
    # Logger.debug("prev #{ix_prev}, next #{ix_next}")

    interp_pair(x, ix_prev, ix_next, xdata, ydata)
  end
end

