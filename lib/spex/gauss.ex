defmodule Spex.Gauss do

	@doc """
  Do a simple [1,2,1] smoothing of a vector. 

  This is a discrete gaussian with kernel size $N=3$ and $\sigma = \sqrt{N-1}/2$.
  Gaussians add by $\sigma^2 = \sigma_0^2 + \sigma_1^2$. 
  Thus, for a $\sqrt{2}$ scale, kernels $N=3$, then $N=5$ have to be applied
  before the signal can be sub-sambled.

  """
  def smooth(yt = %{shape: {_n}}) do
    ye = Nx.concatenate([yt[0..0], yt, yt[-1..-1]])
    yavg = Nx.multiply(Nx.add(ye[0..-2//1], ye[1..-1//1]), 0.5)
    Nx.multiply(Nx.add(yavg[0..-2//1], yavg[1..-1//1]), 0.5)
  end

  def smooth(yt = %{shape: {1,n}}) do
    Nx.reshape(yt, {n}) |> smooth() |> Nx.reshape({1,n})
  end
  def smooth(yt = %{shape: {n,1}}) do
    Nx.reshape(yt, {n}) |> smooth() |> Nx.reshape({n,1})
  end
  def smooth(y) when is_list(y), do: smooth(Nx.tensor(y)) |> Nx.to_flat_list()

  @doc """
  repeat the simple smoothing, eg. use $N=3$ for a resolution halving.
  """
  def smooth(y, 0) do
    y
  end
  def smooth(y, n) do
    smooth(smooth(y), n-1)
  end

  @doc """
  construct a difference-of-gaussians pyramid
  """
  def dog_pyramid_1d(x, 0), do: [x]
  def dog_pyramid_1d(x, n) do
    xs1 = smooth(x, 1)
    dog1 = Nx.subtract(x, xs1)
    xs2 = smooth(xs1, 2)
    dog2 = Nx.subtract(xs1, xs2)
    [dog1, dog2] ++ dog_pyramid_1d(subsample(xs2), n-1)
  end


  def gaussian_pyramid_1d(x, 0), do: [x]
  def gaussian_pyramid_1d(x, n) do
    xs1 = smooth(x, 1)
    xs2 = smooth(xs1, 2)
    [xs1, xs2] ++ gaussian_pyramid_1d(subsample(xs2), n-1)
  end

  def subsample(x = %{shape: {n}}) when rem(n,2) == 1 do
    Nx.concatenate([x, x[-1..-1]])
    |> subsample()
  end
  def subsample(x = %{shape: {n}}) when rem(n,2) == 0 do
  	#Nx.slice seems buggy, so use reduce_window
		a = Nx.reduce_window(x, 0.0, {1}, [strides: [2]], fn (x, _acc) -> 
		  x
		end)
		b = Nx.reduce_window(x, 0.0, {1}, [strides: [2]], fn (x, _acc) -> 
		  x
		end)
		Nx.multiply(Nx.add(a,b), 0.5)
  end
  def subsample(x = %{shape: {1,n}}) do
    Nx.reshape(x, {n}) |> subsample() |> Nx.reshape({1,div(n+1,2)})
  end
  def subsample(x = %{shape: {n,1}}) do
    Nx.reshape(x, {n}) |> subsample() |> Nx.reshape({div(n+1,2),1})
  end

end