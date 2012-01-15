# encoding: utf-8
#
# Jekyll series page generator.
# http://recursive-design.com/projects/jekyll-plugins/
#
# Version: 0.1.4 (201101061053)
#
# Copyright (c) 2010 Dave Perrett, http://recursive-design.com/
# Licensed under the MIT license (http://www.opensource.org/licenses/mit-license.php)
#
# A generator that creates series pages for jekyll sites.
#
# Included filters :
# - series_links:      Outputs the list of series as comma-separated <a> links.
# - date_to_html_string: Outputs the post.date as formatted html, with hooks for CSS styling.
#
# Available _config.yml settings :
# - series_dir:          The subfolder to build series pages in (default is 'series').
# - series_title_prefix: The string used before the series name in the page title (default is
#                          'Series: ').

module Jekyll

  # The SeriesIndex class creates a single series page for the specified series.
  class SeriesIndex < Page

    # Initializes a new SeriesIndex.
    #
    #  +base+         is the String path to the <source>.
    #  +series_dir+ is the String path between <source> and the series folder.
    #  +series+     is the series currently being processed.
    def initialize(site, base, series_dir, series)
      @site = site
      @base = base
      @dir  = series_dir
      @name = 'index.html'
      self.process(@name)
      # Read the YAML data from the layout page.
      self.read_yaml(File.join(base, '_layouts'), 'series_index.html')
      self.data['series']    = series
      # Set the title for this page.
      title_prefix             = site.config['series_title_prefix'] || 'Series: '
      self.data['title']       = "#{title_prefix}#{series}"
      # Set the meta-description for this page.
      meta_description_prefix  = site.config['series_meta_description_prefix'] || 'Series: '
      self.data['description'] = "#{meta_description_prefix}#{series}"
    end

  end

  # The SeriesFeed class creates an Atom feed for the specified series.
  class SeriesFeed < Page

    # Initializes a new SeriesFeed.
    #
    #  +base+         is the String path to the <source>.
    #  +series_dir+ is the String path between <source> and the series folder.
    #  +series+     is the series currently being processed.
    def initialize(site, base, series_dir, series)
      @site = site
      @base = base
      @dir  = series_dir
      @name = 'atom.xml'
      self.process(@name)
      # Read the YAML data from the layout page.
      self.read_yaml(File.join(base, '_includes/custom'), 'series_feed.xml')
      self.data['series']    = series
      # Set the title for this page.
      title_prefix             = site.config['series_title_prefix'] || 'Series: '
      self.data['title']       = "#{title_prefix}#{series}"
      # Set the meta-description for this page.
      meta_description_prefix  = site.config['series_meta_description_prefix'] || 'Series: '
      self.data['description'] = "#{meta_description_prefix}#{series}"

      # Set the correct feed URL.
      self.data['feed_url'] = "#{series_dir}/#{name}"
    end

  end

  # The Site class is a built-in Jekyll class with access to global site config information.
  class Site

    # Creates an instance of SeriesIndex for each series page, renders it, and
    # writes the output to a file.
    #
    #  +series_dir+ is the String path to the series folder.
    #  +series+     is the series currently being processed.
    def write_series_index(series_dir, series)
      index = SeriesIndex.new(self, self.source, series_dir, series)
      index.render(self.layouts, site_payload)
      index.write(self.dest)
      # Record the fact that this page has been added, otherwise Site::cleanup will remove it.
      self.pages << index

      # Create an Atom-feed for each index.
      feed = SeriesFeed.new(self, self.source, series_dir, series)
      feed.render(self.layouts, site_payload)
      feed.write(self.dest)
      # Record the fact that this page has been added, otherwise Site::cleanup will remove it.
      self.pages << feed
    end

    # Loops through the list of series pages and processes each one.
    def write_series_indexes
      if self.layouts.key? 'series_index'
        dir = self.config['series_dir'] || 'series'
        self.series.keys.each do |series|
          self.write_series_index(File.join(dir, series.gsub(/_|\P{Word}/, '-').gsub(/-{2,}/, '-').downcase), series)
        end

      # Throw an exception if the layout couldn't be found.
      else
        throw "No 'series_index' layout found."
      end
    end

  end


  # Jekyll hook - the generate method is called by jekyll, and generates all of the series pages.
  class GenerateSeries < Generator
    safe true
    priority :low

    def generate(site)
      site.write_series_indexes
    end

  end


  # Adds some extra filters used during the series creation process.
  module Filters

    # Outputs a list of series as comma-separated <a> links. This is used
    # to output the series list for each post on a series page.
    #
    #  +series+ is the list of series to format.
    #
    # Returns string
    #
    def series_links(series)
      dir = @context.registers[:site].config['series_dir']
      series = series.sort!.map do |item|
        "<a class='series' href='/#{dir}/#{item.gsub(/_|\P{Word}/, '-').gsub(/-{2,}/, '-').downcase}/'>#{item}</a>"
      end

      case series.length
      when 0
        ""
      when 1
        series[0].to_s
      else
        "#{series[0...-1].join(', ')}, #{series[-1]}"
      end
    end

    # Outputs the post.date as formatted html, with hooks for CSS styling.
    #
    #  +date+ is the date object to format as HTML.
    #
    # Returns string
    def date_to_html_string(date)
      result = '<span class="month">' + date.strftime('%b').upcase + '</span> '
      result += date.strftime('<span class="day">%d</span> ')
      result += date.strftime('<span class="year">%Y</span> ')
      result
    end

  end

end

