defmodule Spex.RefSpec.Mainz do
  @moduledoc """
  Load spectroscopy reference data as available at [www.uv-vis-spectral-atlas-mainz.org](www.uv-vis-spectral-atlas-mainz.org).
  """

  def load!(path) do
    filename = Path.basename(path)

    [formula, source, temperature] =
      Regex.run(~r/(.+)_(.+)_(.+)_.+/, filename, capture: :all_but_first)

    {temp, "K"} = Float.parse(temperature)

    header = %{
      "temperature" => temp,
      "source" => source,
      "formula" => formula
    }

    lines =
      File.read!(path)
      |> String.split(~r{\r\n})

    data =
      for line <- lines do
        for x <- line |> String.split() do
          {y, _} = Float.parse(x)
          y
        end
      end

    {wl, attenuation} = to_spectrum(%{"data" => data})
    header 
    |> Map.put("data", data) 
    |> Map.put(:type, :mainz) 
    |> Map.put(:name, header["formula"]) 
    |> Map.put(:spectrum, %{wavelength: wl, attenuation: attenuation})
  end

  def to_spectrum(%{"data" => data}) do
    wl = for [x, _y] <- data, do: x
    spectrum = for [_x, y] <- data, do: y
    {wl, spectrum}
  end

  def to_norm_spectrum(%{"data" => data}) do
    wl = for [x, _y] <- data, do: x
    spectrum = for [_x, y] <- data, do: y
    spec_tensor = Nx.tensor(spectrum, names: [:wavelength])
    {wl, Nx.divide(spec_tensor, Nx.sum(spec_tensor))}
  end
end
