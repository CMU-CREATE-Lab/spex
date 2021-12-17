defmodule Spex.WebSpec do
  @moduledoc """
  Tools from getting spectrometer data from a standard Apache HTTP server.
  """

  require Logger

  defp parse_listing_row([
         {"td", _, icon_tag},
         {"td", _, name_tag},
         {"td", _, date_tag},
         {"td", _, size_tag},
         {"td", _, _desc}
       ]) do
    [{"img", [{"src", _icon}, {"alt", kind}], _}] = icon_tag
    [{"a", [{"href", path}], _}] = name_tag
    [date] = date_tag
    [size] = size_tag
    {kind, path, date, size}
  end

  @doc """
    This is for scraping the actual directory contents from 
    a standard Apache-style directory index HTML.
  """
  def list_html_dir(url) do
    {:ok, {_status, _headers, dir_listing_html}} = :httpc.request(url)
    {:ok, dir_listing_doc} = Floki.parse_document(dir_listing_html)
    dir_rows = Floki.find(dir_listing_doc, "tr")

    for {"tr", _attribs, cells} <- dir_rows, reduce: [] do
      result ->
        case cells do
          row = [{"td", _, _} | _] ->
            path_desc = parse_listing_row(row)

            case path_desc do
              # ignore the parent dir entry
              {"[PARENTDIR]", _, _, _} -> result
              # just pipe through the path from the rest
              {_kind, path, _, _} -> result ++ [path]
            end

          _ ->
            result
        end
    end
  end

  defp fetch_uvspec_data_file(url) do
    {:ok, {_status, _headers, json_data}} = :httpc.request(url)
    {:ok, spectrometer_data} = Jason.decode(json_data)
    file = Path.basename(url)
    [ts_string] = Regex.run(~r/uvspec_(\d+).json/, file, capture: :all_but_first)
    timestamp = String.to_integer(ts_string)

    spectrometer_data
    |> Map.put("utc_timestamp", DateTime.from_unix!(timestamp) |> DateTime.to_iso8601())
  end

  @doc """
  Get a uvspec data file, from `cache_dir` if it's provided, which it is by default.
  """
  def get_uvspec_data_file(url, cache_dir \\ "uvspec_cache")
  def get_uvspec_data_file(url, nil), do: fetch_uvspec_data_file(url)

  def get_uvspec_data_file(url, cache_dir) do
    file = Path.basename(url)
    cached_path = Path.join(cache_dir, file)

    if File.exists?(cached_path) do
      File.read!(cached_path) |> Jason.decode!()
    else
      data = fetch_uvspec_data_file(url)
      File.write(cached_path, Jason.encode!(data), [:binary])
      data
    end
  end

  def get_uvspec_data_files(url) do
    # filter for files that begin with uvspec
    files = for <<"uvspec" <> _>> = name <- list_html_dir(url), do: name

    cache_dir = "uvspec_cache"
    File.mkdir(cache_dir)

    # Logger.info("getting data from #{url}...")

    data =
      for file <- files do
        get_uvspec_data_file(<<url <> "/" <> file>>, cache_dir)
      end

    Logger.info("getting data from #{url} complete!")
    data
  end

  defp maybe_decode_json(string) when is_binary(string), do: Jason.decode!("[#{string}]")
  defp maybe_decode_json(json), do: json

  @doc """
  Get spectrometer samples from given URL.
  """
  def get_uvspec_samples(data_url) do
    uvspec_samples = Spex.WebSpec.get_uvspec_data_files(data_url)

    # get wavelength info from first sample (all samples should be the same)
    [%{"Wavelengths" => uvspec_wl_json} | _] = uvspec_samples
    uvspec_wl = maybe_decode_json(uvspec_wl_json)

    # get timestamps
    timestamps =
      for sample <- uvspec_samples do
        {:ok, date, _} = DateTime.from_iso8601(sample["utc_timestamp"])
        date
      end

    # get sample data
    signals =
      for sample <- uvspec_samples do
        y = maybe_decode_json(sample["Signals"])
        y
      end

      %{wavelengths: uvspec_wl, timestamps: timestamps, signals: signals}

  end
end