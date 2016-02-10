

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

AWS_BUCKET = 'helgacandys'
AWS_CLOUDFRONT_DISTRIBUTION_ID = 'E110EXKTVLVW59'

AWS_ACCESS_KEY	= ENV['AWS_ACCESS_KEY']
AWS_SECRET      = ENV['AWS_SECRET']

activate :s3_sync do |s3_sync|
	s3_sync.bucket = AWS_BUCKET
	s3_sync.aws_access_key_id =  AWS_ACCESS_KEY
	s3_sync.aws_secret_access_key = AWS_SECRET
	s3_sync.region = 'eu-central-1'
	s3_sync.delete = false
end

activate :cloudfront do |cf|
	cf.access_key_id                    = AWS_ACCESS_KEY
	cf.secret_access_key                = AWS_SECRET
	cf.distribution_id                  = AWS_CLOUDFRONT_DISTRIBUTION_ID

end

activate :deploy do |deploy|
	deploy.method = :git
	deploy.branch = "master"
end

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
