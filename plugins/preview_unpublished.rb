# Monkeypatch for Jekyll
# Introduce distinction between preview/productive site generation
# so posts with YAML attribute `published: false` can be previewed
# on localhost without being published to the productive environment.
# This also now includes hack for series inclusion.

module Jekyll

  class Post
    attr_accessor :series

    def initialize(site, source, dir, name)
      @site = site
      @base = File.join(source, dir, '_posts')
      @name = name

      self.categories = dir.split('/').reject { |x| x.empty? }
      self.process(name)
      self.read_yaml(@base, name)

      #If we've added a date and time to the yaml, use that instead of the filename date
      #Means we'll sort correctly.
      if self.data.has_key?('date')
        # ensure Time via to_s and reparse
        self.date = Time.parse(self.data["date"].to_s)
      end

      if self.data.has_key?('published') && self.data['published'] == false
        self.published = false
      else
        self.published = true
      end

      self.tags = self.data.pluralized_array("tag", "tags")

      if self.categories.empty?
        self.categories = self.data.pluralized_array('category', 'categories')
      end

      self.series = self.data["series"]
    end

    def to_liquid
      self.data.deep_merge({
        "title"      => self.data["title"] || self.slug.split('-').select {|w| w.capitalize! || w }.join(' '),
        "url"        => self.url,
        "date"       => self.date,
        "id"         => self.id,
        "categories" => self.categories,
        "series"     => self.series,
        "next"       => self.next,
        "previous"   => self.previous,
        "tags"       => self.tags,
        "content"    => self.content })
    end
  end

  class Site
    attr_accessor :series

    # patch reset to include series
    def reset
      self.time            = if self.config['time']
                               Time.parse(self.config['time'].to_s)
                             else
                               Time.now
                             end
      self.layouts         = {}
      self.posts           = []
      self.pages           = []
      self.static_files    = []
      self.categories      = Hash.new { |hash, key| hash[key] = [] }
      self.tags            = Hash.new { |hash, key| hash[key] = [] }

      if !self.limit_posts.nil? && self.limit_posts < 1
        raise ArgumentError, "Limit posts must be nil or >= 1"
      end

      self.series = Hash.new { |hash, key| hash[key] = [] }
    end

    # patch render to include series
    def render
      self.posts.each do |post|
        post.render(self.layouts, site_payload)
      end

      self.pages.each do |page|
        page.render(self.layouts, site_payload)
      end

      self.categories.values.map { |ps| ps.sort! { |a, b| b <=> a } }
      self.tags.values.map { |ps| ps.sort! { |a, b| b <=> a } }
      self.series.values.map { |ps| ps.sort! { |a, b| b <=> a } }
    rescue Errno::ENOENT => e
      # ignore missing layout dir
    end
    
    # patch render to include series
    def site_payload
      {"site" => self.config.merge({
          "time"       => self.time,
          "posts"      => self.posts.sort { |a, b| b <=> a },
          "pages"      => self.pages,
          "html_pages" => self.pages.reject { |page| !page.html? },
          "categories" => post_attr_hash('categories'),
          "series"     => self.series,
          "tags"       => post_attr_hash('tags')})}
    end

    # Read all the files in <source>/<dir>/_posts and create a new Post
    # object with each one.
    #
    # dir - The String relative path of the directory to read.
    #
    # Returns nothing.
    def read_posts(dir)
      base = File.join(self.source, dir, '_posts')
      return unless File.exists?(base)
      entries = Dir.chdir(base) { filter_entries(Dir['**/*']) }

      # first pass processes, but does not yet render post content
      entries.each do |f|
        if Post.valid?(f)
          post = Post.new(self, self.source, dir, f)

          # Monkeypatch:
          # On preview environment (localhost), publish all posts
          if ENV.has_key?('OCTOPRESS_ENV') && ENV['OCTOPRESS_ENV'] == 'preview' && post.data.has_key?('published') && post.data['published'] == false
            post.published = true
            # Set preview mode flag (if necessary), `rake generate` will check for it
            # to prevent pushing preview posts to productive environment
            File.open(".preview-mode", "w") {}
          end

          if post.published && (self.future || post.date <= self.time)
            self.posts << post
            post.categories.each { |c| self.categories[c] << post }
            post.tags.each { |c| self.tags[c] << post }

            self.series[post.series] << post unless post.series.nil?
          end
        end
      end

      self.posts.sort!

      # limit the posts if :limit_posts option is set
      self.posts = self.posts[-limit_posts, limit_posts] if limit_posts
    end
  end
end
