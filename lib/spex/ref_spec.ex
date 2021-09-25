defmodule Spex.RefSpec do
  require Nx

  alias Spex.RefSpec.Mainz, as: Mainz
  alias Spex.RefSpec.Hitran, as: Hitran


  @doc """
  remap attenuation parameters from `wl` to `ref_wl`, 
  assuming piecewise-linear approximation, 
  and sample points being in the middle of bins.
  """
  def regressor(wl, attenuation, ref_wl) do
    # re-bin data to match wl data
    y_wl = Spex.Interp.rebin(wl, attenuation, ref_wl)
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

  @doc """
  load uvspec references for the 220-410nm range.
  """
  def load_uvspec_references() do
    refdata_path = Path.join([:code.priv_dir(:spex), "reference-data"])

    [toluene] = Hitran.load_xsc(Path.join([refdata_path, "612d27aa/C7H8_293.0_0.0_35990.0-41285.0_09.xsc"]))
    
    %{
      naphthalene: Mainz.load!(Path.join([refdata_path, "C10H8_Grosch(2015)_296K_200-310nm.txt"])),
      benzene: Mainz.load!(Path.join([refdata_path, "C6H6_Dawes(2017)_298K_115-330nm.txt"])),
      so2: Mainz.load!(Path.join([refdata_path, "SO2_Danielache(2008)_293K_183-350nm(32SO2).txt"])),
      o3: Mainz.load!(Path.join([refdata_path, "O3_Serdyuchenko(2014)_293K_213-1100nm(2013 version).txt"])),
      no2: Mainz.load!(Path.join([refdata_path, "NO2_Bogumil(2003)_293K_230-930nm.txt"])),
      formaldehyde: Mainz.load!(Path.join([refdata_path, "CH2O_MellerMoortgat(2000)_298K_224.56-376.00nm(0.01nm).txt"])),
      phenol: Mainz.load!(Path.join([refdata_path, "C6H5OH_Limao-Vieira(2016)_298K_115.00-334.00nm.txt"])),
      toluene: toluene,
    }
  end


end
