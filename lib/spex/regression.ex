defmodule Spex.Regression do
  import Nx.Defn
  @default_defn_compiler EXLA

  @doc """
  Compute a linear regression for $\beta$ being of shape {m,1}, $X$ being an {n,m} regressor matrix, and $Y$ an {n,1} shaped obeservation vector.

  ### Linear Regression

  Linear regression estimates the parameters $\beta$ in a system of the form
  $$
  y \approx \beta_0 + \sum_{j=1}^m \beta_j \times x_j
  $$
  where $x$ is the independent variable, and $y$ is the output. In matrix form
  $$
  Y = X \bar{\beta} + \epsilon
  $$
  with $\epsilon$ being the error term.

  Forming a system of equations for many samples $y_i$, 
  the resultant system of equations can be solved.
  $$
  X^T X \bar{\beta} = X^T Y
  $$
  and thus
  $$
  \bar{\beta} = \left( X^T X\right)^{-1} X^T Y
  $$

  The model has $m$ independent variables, and $n$ data points. 
  Thus, $\bar{\beta}$ is a $m \times 1$ vector,
  $Y$ is $n \times 1$, and X is $n \times m$ matrix.
  That makes $(X^T X)$ an $m \times m$ matrix, 
  and with $m \ll n$, that should be an easy matrix inversion.

  ### Regression for Spectra

  For UV-spectra, the $y_i$ are the signal intensities at each wavelength,
  and each $x_i$ row is the absorbance coefficients for the specific gases.

  """
  def linreg(x, y) do
    x = Nx.backend_transfer(x, EXLA.DeviceBackend)
    y = Nx.backend_transfer(y, EXLA.DeviceBackend)
    linregn(x,y) |> Nx.backend_transfer()
  end

  defnp linregn(x, y) do
    xtx = Nx.dot(Nx.transpose(x), x)
    xty = Nx.dot(Nx.transpose(x), y)
    # IO.puts("xtx.shape = #{inspect(Nx.shape(xtx))}")
    # IO.puts("xty.shape = #{inspect(Nx.shape(xty))}")
    Nx.LinAlg.solve(xtx, xty)
  end

  def ridgereg(x, y, k) do
    x = Nx.backend_transfer(x, EXLA.DeviceBackend)
    y = Nx.backend_transfer(y, EXLA.DeviceBackend)
    # xtx = Nx.dot(Nx.transpose(x), x)
    # xty = Nx.dot(Nx.transpose(x), y) |> Nx.backend_transfer(EXLA.DeviceBackend)
    # kip = Nx.eye(xtx) |> Nx.multiply(k)
    # xtx_kip = Nx.add(xtx, kip) |> Nx.backend_transfer(EXLA.DeviceBackend)
    # Nx.LinAlg.solve(xtx_kip, xty)
    ridgeregn(x, y, k) |> Nx.backend_transfer()
  end

  defnp ridgeregn(x, y, k) do
    xtx = Nx.dot(Nx.transpose(x), x)
    xty = Nx.dot(Nx.transpose(x), y)
    kip = Nx.eye(xtx) |> Nx.multiply(k)
    xtx_kip = Nx.add(xtx, kip)
    # IO.puts("xtx.shape = #{inspect(Nx.shape(xtx))}")
    # IO.puts("xty.shape = #{inspect(Nx.shape(xty))}")
    Nx.LinAlg.solve(xtx_kip, xty)
  end

end