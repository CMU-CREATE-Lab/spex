defmodule Spex.RefSpec.JcampDx do
  @moduledoc """
  Parse JCAMP-DX spectrum files.

  The files have line starting with `##` as directives, 
  and X,Y data after `##XYPOINTS=(XY..XY)`, the end is marked by `##END=`
  """

  defp parse_jcamp(lines, header \\ %{}, state \\ {:header, ""})
  defp parse_jcamp([_line = <<"##END=">> | _lines], header, _state), do: post_process(header)

  defp parse_jcamp([_line = <<"##", directive::binary>> | lines], header, {:header, _}) do
    [name, value] = String.split(directive, "=")
    header = header |> Map.put(name, value)
    parse_jcamp(lines, header, {:header, name})
  end

  defp parse_jcamp([line | lines], header, {:header, name}) do
    value = Enum.join([header[name], line], "\n")
    header = header |> Map.put(name, value)
    parse_jcamp(lines, header, {:header, name})
  end

  defp post_process(header = %{"XYPOINTS" => xy_str = <<"(XY..XY)\n", _::binary>>}) do
    ["(XY..XY)" = _format | sample_lines] = xy_str |> String.split("\n") |> Enum.dedup()

    samples =
      for line <- sample_lines do
        sample = line |> String.split(",")
        for coord <- sample, do: coord |> String.to_float()
      end

    header =
      header
      |> Map.put("XYPOINTS", samples)
      |> Map.put("MINX", header["MINX"] |> String.to_float())
      |> Map.put("MINY", header["MINY"] |> String.to_float())
      |> Map.put("MAXX", header["MAXX"] |> String.to_float())
      |> Map.put("MAXY", header["MAXY"] |> String.to_float())
      |> Map.put("FIRSTX", header["FIRSTX"] |> String.to_float())
      |> Map.put("FIRSTY", header["FIRSTY"] |> String.to_float())
      |> Map.put("LASTX", header["LASTX"] |> String.to_float())

    # |> Map.put("LASTY", header["LASTY"] |> String.to_float())
    post_process(header)
  end

  defp post_process(header = %{"XYPOINTS" => samples, "YUNITS" => "Logarithm epsilon"}) do
    samples =
      for [x, y] <- samples do
        [x, :math.exp(y)]
      end

    {wl, attenuation} = to_spectrum(%{"XYPOINTS" => samples})

    header = 
      header
      |> Map.put("XYPOINTS", samples)
      |> Map.put("YUNITS", "epsilon")
      |> Map.put("MINY", header["MINY"] |> :math.exp())
      |> Map.put("MAXY", header["MAXY"] |> :math.exp())
      |> Map.put("FIRSTY", header["FIRSTY"] |> :math.exp())
      |> Map.put(:spectrum, %{wavelength: wl, attenuation: attenuation})

    # |> Map.put("LASTY", header["LASTY"] |> :math.exp())
    post_process(header)
  end

  defp post_process(header), do: header

  @doc """
  load JCAMP-DX spectrum format file
  """
  def load!(path) do
    str = File.read!(path)
    lines = String.split(str, "\n")
    parse_jcamp(lines)
  end

  def to_spectrum(_jcamp = %{"XYPOINTS" => samples}) do
    wavelengths = for [x, _] <- samples, do: x
    values = for [_, y] <- samples, do: y
    {wavelengths, values}
  end

  def to_norm_spectrum(_jcamp = %{"XYPOINTS" => samples}) do
    wavelengths = for [x, _] <- samples, do: x
    values = for [_, y] <- samples, do: y
    tensor = values |> Nx.tensor(backend: Nx.BinaryBackend)

    {wavelengths, Nx.divide(tensor, Nx.sum(tensor))}
  end
end
