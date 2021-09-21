defmodule Spex.RefSpec.Hitran do
  @moduledoc """
  Parse Hitran spectrum files
  """

  defp parse_xsc_block(lines, blocks \\ [])
  defp parse_xsc_block([], blocks), do: blocks
  defp parse_xsc_block([""], blocks), do: blocks

  defp parse_xsc_block([header_line | lines], blocks) do
    <<
      molecule::binary-20,
      vmin::binary-10,
      vmax::binary-10,
      num_samples::binary-7,
      temperature::binary-7,
      pressure::binary-6,
      rhomax::binary-10,
      resolution::binary-5,
      name::binary-15,
      _::binary-4,
      broadener::binary-3,
      reference::binary-3
    >> = header_line

    header = %{
      molecule: String.trim(molecule),
      vmin_per_cm: vmin |> String.trim() |> String.to_float(),
      vmax_per_cm: vmax |> String.trim() |> String.to_float(),
      num_samples: num_samples |> String.trim() |> String.to_integer(),
      temperature_K: temperature |> String.trim() |> String.to_float(),
      pressure_Torr: pressure |> String.trim() |> String.to_float(),
      rhomax_cm2: rhomax |> String.trim() |> String.to_float(),
      resolution: resolution |> String.trim() |> String.to_float(),
      name: String.trim(name),
      broadener: broadener,
      reference: reference |> String.trim() |> String.to_integer(),
      data: []
    }

    parse_xsc_block(lines, header, blocks)
  end

  defp parse_xsc_block([], header, []), do: [header]
  defp parse_xsc_block([line | lines], header = %{data: data, num_samples: num_samples}, blocks) do
    num_data = Enum.count(data)

    cond do
      num_data < num_samples ->
        samples = for str <- String.split(line), do: str |> String.to_float()
        header = header |> Map.put(:data, data ++ samples)
        parse_xsc_block(lines, header, blocks)

      true ->
        parse_xsc_block([line | lines], blocks ++ [header])
    end
  end

  def load_xsc(path) do
    str = File.read!(path)
    lines = String.split(str, "\n")
    xscs = parse_xsc_block(lines)
    # generate wavelength, attenuateion data
    for xsc <- xscs do
      {wl, attenuation} = to_spectrum(xsc)
      xsc |> Map.put(:type, :hitran) |> Map.put(:spectrum, %{wavelength: wl, attenuation: attenuation})
    end
  end

  def to_spectrum(%{
        data: data,
        vmax_per_cm: vmax,
        vmin_per_cm: vmin,
        num_samples: num_samples
      }) do
    vstep = (vmax - vmin) / (num_samples - 1)
    lambdas = for x <- 0..(num_samples - 1), do: 1.0e7 / (vmin + x * vstep)
    {Enum.reverse(lambdas), Enum.reverse(data)}
  end

  def normalize_spectrum(data) do
    tensor = Nx.tensor(data, backend: Nx.BinaryBackend)
    norm = Nx.divide(tensor, Nx.sum(tensor))
    norm
  end

  def to_norm_spectrum(hitran_data) do
    {wl, data} = to_spectrum(hitran_data)
    norm_data = normalize_spectrum(data)
    {wl, norm_data}
  end
end
