module Jekyll
  class SeriesListTag < Liquid::Tag
    def render(context)
      html = ""
      series = context.registers[:site].series.keys
      series.sort.each do |s|
        posts_in_series = context.registers[:site].series[s].size
        series_dir = context.registers[:site].config['series_dir']
        series_url = File.join(series_dir, s.gsub(/_|\P{Word}/, '-').gsub(/-{2,}/, '-').downcase)
        html << "<li class='series'><a href='/#{series_url}/'>#{s} (#{posts_in_series})</a></li>\n"
      end
      html
    end
  end
end

Liquid::Template.register_tag('series_list', Jekyll::SeriesListTag)
