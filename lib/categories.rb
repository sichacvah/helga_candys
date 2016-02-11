module Categories
  def generate_categories
    sitemap.resources.map { |res| res.data.category }.uniq.sort
  end
end
