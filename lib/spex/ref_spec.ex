defmodule Spex.RefSpec do
  require Nx

  def regressor(wl, abs, ref_wl) do
    # re-bin data to match wl data
    y_wl = Spex.Interp.rebin(wl, abs, ref_wl)
    Nx.tensor([y_wl])
  end

  def regressor(%{:spectrum => %{wavelength: x, attenuation: y}}, wl) do
    regressor(x,y,wl)
  end


  def minmax_wavelengths_all([%{:spectrum => %{wavelength: x}} | spectra]) do
    minmax_wavelengths_all(spectra, {Enum.min(x), Enum.max(x)})
  end
  def minmax_wavelengths_all([], minmax) do
    minmax
  end
  def minmax_wavelengths_all([%{:spectrum => %{wavelength: x}} | spectra], {wlmin,wlmax}) do
    minmax_wavelengths_all(spectra, {max(wlmin, Enum.min(x)), min(wlmax, Enum.max(x))})
  end

end
