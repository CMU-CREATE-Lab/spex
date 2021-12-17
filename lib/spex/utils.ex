defmodule Spex.Utils do
	require Nx

  import Nx.Defn
  # @default_defn_compiler EXLA



	@doc """
	create finite difference of vectors / matrices on a given axis
	"""
	def diff(a) do
    Nx.subtract(a[1..-1//1], a[0..-2//1])
  end
  def diff(a, axis: 0) do
    Nx.subtract(a[1..-1//1], a[0..-2//1])
  end
  def diff(a, axis: 1) do
    Nx.transpose(Nx.subtract(Nx.transpose(a)[1..-1//1], Nx.transpose(a)[0..-2//1]))
  end

  @doc """
  Convert a signal and reference to attenuation.
  """
  def signal_to_attenuation(signal, ref_signal) do
    signal_norm = Nx.divide(signal, ref_signal)
    _signal_attenuated = Nx.multiply(Nx.log(signal_norm), -1.0)
  end

  @doc """
  for generating a slice range of a series that can be used to slice similar data, eg. corresponding x,y vectors
  """
  def in_range(series, minv, maxv) do
    imax = Enum.count(series, fn x -> x < maxv end)
    imin = Enum.count(series, fn x -> x < minv end)
    imin..(imax-1)
  end

  @doc """
  perform a linear regression based on the slope of the signal.

  Returns x,b to make it possible to reconstruct the estimated signal.

  """
  def slope_regression(signal, ref_signal, wl, regressors, opts \\ []) do
    wlmin = Keyword.get(opts, :wlmin, 220)
    wlmax = Keyword.get(opts, :wlmax, 310)
    imax = Enum.count(wl, fn x -> x < wlmax end)
    imin = Enum.count(wl, fn x -> x < wlmin end)
    regd_range = imin..(imax-2)

    y = signal_to_attenuation(signal, ref_signal)
    yd = y |> diff()
    yd = yd[regd_range]
    regd = for(reg <- regressors, do: diff(reg, axis: 1))
    onesd = Nx.tensor([for(_i <- 1..(Enum.count(wl)-1), do: 1.0e-3)])
    xd = Nx.concatenate([onesd | regd], axis: 0) |> Nx.transpose()
    xd = xd[regd_range] 

    reg_range = imin..(imax-1)
    ones = Nx.tensor([for(_i <- 1..Enum.count(wl), do: 0.0e-0)])
    x = Nx.concatenate([ones | regressors], axis: 0) |> Nx.transpose()
    x = x[reg_range] 

    {x, Spex.Regression.linreg(xd,yd)}
    # {x, Spex.Regression.ridgereg(xd,yd, 1.0e-30)}
  end

  @doc """
  do a combined slope, then value regression. regressors are of the format `{name, regressor}`.
  """
  def slope_value_regression(signal, ref_signal, wl, slope_regressors, value_regressors, opts \\ []) do
    wlmin = Keyword.get(opts, :wlmin, 220)
    wlmax = Keyword.get(opts, :wlmax, 310)
    imax = Enum.count(wl, fn x -> x < wlmax end)
    imin = Enum.count(wl, fn x -> x < wlmin end)
    regd_range = imin..(imax-2)

    y = signal_to_attenuation(signal, ref_signal)
    yd = y |> diff()
    yd = yd[regd_range]
    regd = for({_name, reg} <- slope_regressors, do: diff(reg, axis: 1))
    onesd = Nx.tensor([for(_i <- 1..(Enum.count(wl)-1), do: 1.0e-3)])
    xd = Nx.concatenate([onesd | regd], axis: 0) |> Nx.transpose()
    xd = xd[regd_range] 


    # first regression runs on the slopes of the signal
    bd = Spex.Regression.linreg(xd,yd)

    # second regression on value, but after initial model has been subtracted
    # compute X tensor for signal reconstruction (ignores constant first term of model, hence ones is actually zeroes)
    reg_range = imin..(imax-1)
    regs = for({_name, reg} <- slope_regressors, do: reg)
    ones = Nx.tensor([for(_i <- 1..Enum.count(wl), do: 0.0e-0)])
    xs = Nx.concatenate([ones | regs], axis: 0) |> Nx.transpose()
    xs = xs[reg_range] 

    y_regd = Nx.dot(xs, bd)
    y_slope = Nx.subtract(y, y_regd)

    # recompute X matrix for value regression
    regs = for({_name, reg} <- value_regressors, do: reg)
    ones = Nx.tensor([for(_i <- 1..Enum.count(wl), do: 1.0e-0)])
    xv = Nx.concatenate([ones | regs], axis: 0) |> Nx.transpose()
    xv = xv[reg_range] 

    # use y_sloped, eg. input signal with slope results subtracted
    bv = Spex.Regression.linreg(xv,y_slope)

    y_reg = Nx.dot(xv, bv)

    # combine b values across slope and value regressors
    slope_params = for {{name, _reg}, b} <- Enum.zip(slope_regressors, bd |> Nx.to_flat_list() |> Enum.slice(1..-1//1)) do
      {name, b}
    end
    value_params = for {{name, _reg}, b} <- Enum.zip(value_regressors, bv |> Nx.to_flat_list() |> Enum.slice(1..-1//1)) do
      {name, b}
    end
    all_params = for {name, b} <- slope_params ++ value_params, reduce: %{} do
      acc ->
        Map.update(acc, name, b, fn b_old -> b_old + b end)
    end
    |> Enum.to_list()
    |> Enum.sort_by(fn {name, _} -> name end)

    combined_names = for {name, _b} <- all_params, do: name

    # add the ones
    const_param = {:const, bv |> Nx.to_flat_list() |> Enum.at(0)}
    all_params = [const_param |  all_params]


    # recompute X matrix for combined regression
    combined_regressors = for name <- combined_names, do: Keyword.get(slope_regressors, name) || Keyword.get(value_regressors, name)

    # IO.puts("combined_regressors=#{inspect(combined_regressors)}")

    ones = Nx.tensor([for(_i <- 1..Enum.count(wl), do: 1.0e-0)])
    x = Nx.concatenate([ones | combined_regressors], axis: 0) |> Nx.transpose()
    x = x[reg_range] 

    # IO.puts("x=#{inspect(x)}")

    %{
      x_slope: xs, x_value: xv,
      b_slope: bd, b_value: bv, 
      y_slope: y_slope, y_value: y_reg,
      combined_x: x,
      combined_params: all_params,
    }

  end

  @doc """
  perform a linear regression based on the first Difference-of-Gaussians.

  Returns x,b to make it possible to reconstruct the estimated signal.

  """
  def dog_regression(signal, ref_signal, wl, regressors, opts \\ []) do
    wlmin = Keyword.get(opts, :wlmin, 220)
    wlmax = Keyword.get(opts, :wlmax, 310)
    imax = Enum.count(wl, fn x -> x < wlmax end)
    imin = Enum.count(wl, fn x -> x < wlmin end)
    regd_range = imin..(imax-2)

    y = signal_to_attenuation(signal, ref_signal)
    yd = Nx.subtract(y, Spex.Gauss.smooth(y, 3))
    yd = yd[regd_range]
    regd = for(reg <- regressors, do: Nx.subtract(reg, Spex.Gauss.smooth(reg, 3)))
    onesd = Nx.tensor([for(_i <- 1..(Enum.count(wl)), do: 1.0e-3)])
    xd = Nx.concatenate([onesd | regd], axis: 0) |> Nx.transpose()
    xd = xd[imin..(imax-2)] 

    reg_range = imin..(imax-1)
    ones = Nx.tensor([for(_i <- 1..Enum.count(wl), do: 0.0e-0)])
    x = Nx.concatenate([ones | regressors], axis: 0) |> Nx.transpose()
    x = x[reg_range] 

    {x, Spex.Regression.linreg(xd,yd)}
    # {x, Spex.Regression.ridgereg(xd,yd, 1.0e-30)}
  end


  @doc """
  perform a linear regression based on the value of the signal.

  Returns x,b to make it possible to reconstruct the estimated signal.

  """
  def value_regression(signal, ref_signal, wl, regressors, opts \\ []) do
    wlmin = Keyword.get(opts, :wlmin, 210)
    wlmax = Keyword.get(opts, :wlmax, 310)
    imax = Enum.count(wl, fn x -> x < wlmax end)
    imin = Enum.count(wl, fn x -> x < wlmin end)
    reg_range = imin..(imax-1)

    y = signal_to_attenuation(signal, ref_signal)[reg_range]
    ones = Nx.tensor([for(_i <- 1..Enum.count(wl), do: 1.0)])
    x = Nx.concatenate([ones | regressors], axis: 0) |> Nx.transpose()
    x = x[reg_range] 
    b = Spex.Regression.linreg(x,y)
    {x, b}
  end

  def tls_regression(signal, ref_signal, wl, regressors, opts \\ []) do
    wlmin = Keyword.get(opts, :wlmin, 210)
    wlmax = Keyword.get(opts, :wlmax, 310)
    imax = Enum.count(wl, fn x -> x < wlmax end)
    imin = Enum.count(wl, fn x -> x < wlmin end)
    reg_range = imin..(imax-1)

    y = signal_to_attenuation(signal, ref_signal)[reg_range]
    ones = Nx.tensor([for(_i <- 1..Enum.count(wl), do: 1.0)])
    x = Nx.concatenate([ones | regressors], axis: 0) |> Nx.transpose()
    x = x[reg_range] 
    b = Spex.Regression.tls_reg(x,y)
    {x, b}
  end

  @doc """
  cumulative sum over `axis`, default is axis 0.
  """
  def cumsum(a, opts \\ []) do
    axis = Keyword.get(opts, :axis, 0)
    as = Nx.shape(a)
    n = elem(as, axis)
    case n do
      1 -> a
      n ->
        # FIXME: defn impl does not work yet
        # cumsumn(a, Nx.tensor(Tuple.to_list(as)), axis, n)
        acc = Nx.slice(a, Tuple.to_list(put_elem(as, axis, 0)), Tuple.to_list(put_elem(as, axis, 1)))
        {result, _acc} = for i <- 2..n, reduce: {acc, acc} do
          {dst, acc} ->
           src = Nx.slice(a, Tuple.to_list(put_elem(as, axis, i-1)), Tuple.to_list(put_elem(as, axis, 1)))
           acc = Nx.add(acc, src)
           {Nx.concatenate([dst, acc], axis: axis), acc}
        end
        result  
    end
  end

  @doc """
  Compute H matrix for residual computation `Y-HY`.
  """
  def h(x) do
    xtx = Nx.dot(Nx.transpose(x), x)
    xtx_inv = Nx.LinAlg.invert(xtx)
    Nx.dot(x, Nx.dot(xtx_inv, Nx.transpose(x)))
  end
 
  # defnp cumsumn(a, as, axis, n) do
  #   shape0 = Nx.put_slice(as, [axis], 0)
  #   shape1 = Nx.put_slice(as, [axis], 1)
  #   acc = Nx.slice(a, shape0, shape1)
  #   {result, _acc} = for i <- 2..n, reduce: {acc, acc} do
  #     {dst, acc} ->
  #       shapei = Nx.put_slice(as, [axis], i-1)
  #      src = Nx.slice(a, shapei, shape1)
  #      acc = Nx.add(acc, src)
  #      {Nx.concatenate([dst, acc], axis: axis), acc}
  #   end
  #   result  
  # end


end
