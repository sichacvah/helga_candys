
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
activate :directory_indexes
activate :i18n, :mount_at_root => :ru, :no_fallbacks => true



AWS_BUCKET = 'helgabakes.com'
AWS_CLOUDFRONT_DISTRIBUTION_ID = 'E36WX0OE0KOWHO'

AWS_ACCESS_KEY = ENV['AWS_ACCESS_KEY']
AWS_SECRET = ENV['AWS_SECRET']


activate :s3_sync do |s3_sync|
	s3_sync.bucket = AWS_BUCKET
	s3_sync.aws_access_key_id =  AWS_ACCESS_KEY
	s3_sync.aws_secret_access_key = AWS_SECRET
	s3_sync.region = 'eu-central-1'
	s3_sync.delete = true
end

activate :cloudfront do |cf|
	cf.access_key_id                    = AWS_ACCESS_KEY
	cf.secret_access_key                = AWS_SECRET
	cf.distribution_id                  = AWS_CLOUDFRONT_DISTRIBUTION_ID
end


activate :blog do |blog|
  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"
	blog.permalink = "categories/{category}/posts/{title}"
	blog.default_extension = ".markdown"
	blog.layout = "layouts/post"
	blog.sources = "posts/{category}/{title}"
	blog.summary_separator = /SPLIT_SUMMARY_BEFORE_THIS/
	blog.custom_collections = {
		category: {
			link: '/categories/{category}/posts.html',
			template: '/post.html'
		}
	}
end

page "/feed.xml", layout: false
page "/contacts.html", layout: "layouts/post"
configure :development do
  activate :livereload
end

configure :build do
	activate :minify_css
	activate :minify_javascript
	activate :asset_hash
end
