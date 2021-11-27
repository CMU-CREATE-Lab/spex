defmodule Spex.Interp do
  @moduledoc """
  Interpolate data.
  """

  # import Nx.Defn
  # @defn_compiler EXLA

  @doc """
  Search in a list/array for data for first index where predicate is false.

  Assumes that the predicate behaves monotonically.
  Only really useful for arrays like `Nx.Tensor` to stay O(log n).
  """
  def binsearch_pred(data, fun) do
    len = vector_length(data)
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
        pred = fun.(data[mid] |> Nx.to_scalar())
        # Logger.debug("lo #{Nx.to_scalar(lo)}, hi #{Nx.to_scalar(hi)}, pred #{inspect(pred)}")
        if !pred do
          binsearch_pred(data, fun, mid + 1, hi)
        else
          binsearch_pred(data, fun, lo, mid)
        end
    end
  end

  @doc """
  Get length of single column vector, whether shape is 1D or 2D.
  """
  def vector_length(x) when is_list(x), do: Enum.count(x)
  def vector_length(x) do
    case Nx.shape(x) do
      {len} -> len
      {len, 1} -> len
    end
  end

  @doc """
  Interpolate data linearly. `xdata` must be monotonically increasing
  """
  def interp(x, xdata, ydata, opts \\ [])
  def interp(x, xdata, ydata, _opts) do
    len = vector_length(xdata)
    ix_next = binsearch_pred(xdata, fn v -> Nx.to_scalar(v) > x end)
    ix_prev = max(ix_next - 1, 0)
    ix_next = min(ix_next, len - 1)
    # Logger.debug("prev #{ix_prev}, next #{ix_next}")

    interp_pair(x, ix_prev, ix_next, xdata, ydata)
  end


  @doc """
  Interpolate data linearly with a mapping function. `xdata` must be monotonically increasing.

  `fun` takes an argument of (y), and is called with each y0, y1 to transform the value to be interpolated.
  """
  def interp_f(x, xdata, ydata, fun)
  def interp_f(x, xdata, ydata, fun) do
    len = vector_length(xdata)
    ix_next = binsearch_pred(xdata, fn v -> Nx.to_scalar(v) > x end)
    ix_prev = max(ix_next - 1, 0)
    ix_next = min(ix_next, len - 1)
    # Logger.debug("prev #{ix_prev}, next #{ix_next}")

    interp_pair_f(x, ix_prev, ix_next, xdata, ydata, fun)
  end


  @doc """
  re-bin x,y samples for a different x sampling.

  We assume the input samples form a piecewise linear function, 
  and the resampling will weigh each input sample accordingly inside each bin. 
  This ensures that the input can be irregular. As samples are assumed as mid points,
  this works best if xout is regularly spaced.
  """
  def rebin(xin, yin, xout, opts \\ [])
  def rebin(xin, yin, xout, _opts) do
    xt = Nx.tensor(xout)
    # we define the bin limits as halfway between sample points
    # but also extend first and last bins so they're not half-width
    xa = Nx.concatenate([Nx.subtract(xt[0..0], Nx.subtract(xt[1], xt[0])), xt])
    xb = Nx.concatenate([xt, Nx.add(xt[-1..-1], Nx.subtract(xt[-1..-1], xt[-2..-2]))])
    bin_limit_x = Nx.multiply(0.5, Nx.add(xa, xb))

    xin_tensor = Nx.tensor(xin)
    yin_tensor = Nx.tensor(yin)

    bin_limit_y = Nx.map(bin_limit_x, fn (x) -> interp(Nx.to_scalar(x), xin_tensor, yin_tensor) end)

    # the bins are filled so that they have a continuous piecewise function in them, 
    # including interpolated samples at upper and lower limits

    # Add upper limit samples to bins.
    # binned_samples is a map so that values above/below xout limits do not pose problems,
    # but it has to be later converted back to a list for final integration.
    # The insertions happen in reverse order, from hi to lo, as we're appending lists, 
    # and adding a head is O(1), while adding at tail is O(n).
    upper_limits = List.zip([Nx.to_flat_list(bin_limit_x[1..-1//1]), Nx.to_flat_list(bin_limit_y[1..-1//1])])
    binned_samples = for {{x,y}, i} <- Enum.with_index(upper_limits), reduce: %{} do
      acc ->
        # IO.puts("v=#{inspect(v)}")
        Map.update(acc, i, [{x,y}], fn entries -> [{x,y} | entries] end)
    end

    # sort the input samples into the output bins
    binned_samples = for {x,y} <- Enum.reverse(List.zip([xin, yin])), reduce: binned_samples do
      acc ->
        i = -1 + binsearch_pred(bin_limit_x, fn (l) -> x < l end)
        Map.update(acc, i, [{x,y}], fn entries -> [{x,y} | entries] end)
    end

    # and finally add lower limit samples
    lower_limits = List.zip([Nx.to_flat_list(bin_limit_x[0..-2//1]), Nx.to_flat_list(bin_limit_y[0..-2//1])])
    binned_samples = for {{x,y}, i} <- Enum.with_index(lower_limits), reduce: binned_samples do
      acc ->
        Map.update(acc, i, [{x,y}], fn entries -> [{x,y} | entries] end)
    end

    # convert binned_samples map back to list
    binned_samples = for i <- 1..(Enum.count(xout)), into: [] do
      binned_samples[i-1]
    end

    # now we need to evaluate the piecewise linear function in each bin to arrive at the result
    integrated_samples = for bin <- binned_samples do
      llim = Enum.slice(bin, 0..-2//1)
      ulim = Enum.slice(bin, 1..-1//1)
      # piecewise trapezoid integration
      trap = for {{lx, ly}, {ux, uy}} <- Enum.zip(llim, ulim), do: (ux-lx)*0.5*(ly+uy)
      {xlo, _y} = Enum.at(llim,0)
      {xhi, _y} = Enum.at(ulim,-1)
      Enum.sum(trap) / (xhi-xlo)
    end

    integrated_samples
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

  defp interp_pair_f(_x, i_prev, i_prev, _xdata, ydata, fun) do
    fun.(ydata[i_prev])
  end

  defp interp_pair_f(x, i_prev, i_next, xdata, ydata, fun) do
    {x_prev, x_next} = {xdata[i_prev], xdata[i_next]}
    sx = Nx.subtract(x_next, x_prev)
    dx = Nx.subtract(x, x_prev)
    u = Nx.divide(dx, sx)
    u1 = Nx.subtract(1.0, u)
    Nx.add(Nx.multiply(fun.(ydata[i_prev]), u1), Nx.multiply(fun.(ydata[i_next]), u))
  end


end

