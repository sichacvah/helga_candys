###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
###
# Helpers
###

activate :blog do |blog|
  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"
	blog.permalink = "categories/{category}/posts/{title}"
	blog.default_extension = ".markdown"
	blog.layout = "layout"
	blog.sources = "posts/{category}/{title}"
	blog.summary_separator = /SPLIT_SUMMARY_BEFORE_THIS/
#	blog.custom_collections = {
#		category: {
#			link: '/categories/{category}/posts.html',
#			template: '/category.html'
#		}
#	}
end

page "/feed.xml", layout: false
configure :development do
  activate :livereload
end

configure :build do
end
