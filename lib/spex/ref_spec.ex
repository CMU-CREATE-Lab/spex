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
      benzene: Mainz.load!(Path.join([refdata_path, "C6H6_Dawes(2017)_298K_115-330nm.txt"])),
      naphthalene: Mainz.load!(Path.join([refdata_path, "C10H8_Grosch(2015)_296K_200-310nm.txt"])),
      m_xylene: Mainz.load!(Path.join([refdata_path, "m-(CH3)2C6H4_Fally(2009)_293K_242.132-285.713nm.txt"])),
      o_xylene: Mainz.load!(Path.join([refdata_path, "o-(CH3)2C6H4_Fally(2009)_293K_242.132-285.713nm.txt"])),
      p_xylene: Mainz.load!(Path.join([refdata_path, "p-(CH3)2C6H4_Fally(2009)_293K_242.132-285.713nm.txt"])),
      # p_xylene2: Mainz.load!(Path.join([refdata_path, "p-(CH3)2C6H4_Bolovinos(1982)_298K_139.4-279.5nm.txt"])),
      h2s: Mainz.load!(Path.join([refdata_path, "H2S_Grosch(2015)_294.8K_198-370nm.txt"])),
      so2: Mainz.load!(Path.join([refdata_path, "SO2_Danielache(2008)_293K_183-350nm(32SO2).txt"])),
      # o2: Mainz.load!(Path.join([refdata_path, "O2_JPL-2010(2011)_298K_205-245nm(rec).txt"])),
      ozone: Mainz.load!(Path.join([refdata_path, "O3_Serdyuchenko(2014)_293K_213-1100nm(2013 version).txt"])),
      # ozone_720k: Mainz.load!(Path.join([refdata_path, "O3_Astholz(1982)_720K_210-325nm.txt"])),
      no2: Mainz.load!(Path.join([refdata_path, "NO2_Bogumil(2003)_293K_230-930nm.txt"])),
      n2o: Mainz.load!(Path.join([refdata_path, "N2O_JohnstonGraham(1974)_298K_190-315nm.txt"])),
      formaldehyde: Mainz.load!(Path.join([refdata_path, "CH2O_MellerMoortgat(2000)_298K_224.56-376.00nm(0.01nm).txt"])),
      phenol: Mainz.load!(Path.join([refdata_path, "C6H5OH_Limao-Vieira(2016)_298K_115.00-334.00nm.txt"])),
      toluene: toluene,
    }
  end

  def molecular_masses() do
    %{
      benzene: 78.114,
      m_xylene: 106.16,
      p_xylene: 106.16,
      o_xylene: 106.16,
      ozone: 47.997,
      ozone_720k: 47.997,
      toluene: 92.141,
      naphthalene: 128.174,
      h2s: 32.08,
      so2: 64.066,
      n2o: 44.013,
      no2: 46.006,
      o2: 31.9988,
      formaldehyde: 30.026,
      phenol: 94.113,
    }
  end

  @doc """
  Remap references to given wavelength and smooth once.
  """
  def remap_references(refs, ref_wl) when is_map(refs) do
    Map.to_list(refs) |> remap_references(ref_wl) |> Map.new()
  end
  def remap_references(refs, ref_wl) do
    for {name, reference = %{spectrum: %{attenuation: attenuation, wavelength: wl}}} <- refs do
      att = Spex.Interp.rebin(wl, attenuation, ref_wl) |> Spex.Gauss.smooth()
      {name, put_in(reference.spectrum, %{attenuation: att, wavelength: ref_wl})}
    end

  end

end
