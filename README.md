# Issue

# Application

Steps to reproduce the issue

1. `rails new --database=postgresql bullet-performance-app`
2. `be rails generate scaffold Article title:string body:text`
3. `be rails generate scaffold Comment body:text author:string article:references`
4. `rails db:migrate`
5. Adjust `_comment.html.erb` to reference Article field `<%= comment.article.title %>`
6. Adjust CommentsController:
```
 def index
    @comments = Comment.preload(:article).first(5_000)
  end
```
7. Add bullet gem
```
  config.after_initialize do
    Bullet.enable = true
    Bullet.rails_logger = true
  end
```
8. Seed database with data:
```
ActiveRecord::Base.connection.transaction do
  articles = 10_000.times.map do
    { title: "Article #{SecureRandom.hex{8}}", body: "Some body" }
  end

  article_ids = Article.upsert_all(articles, returning: [:id]).map { |x| x["id" ]}
  comments = article_ids.map do |ar_id|
    { body:"Comment #{SecureRandom.hex{8}}", author: "Author #{SecureRandom.hex{8}}" , article_id: ar_id }
  end
  Comment.upsert_all(comments)
end
```
10. Notice significant performance issues when accessing `/comments` page AFTER the request has been complete by Rails.
11. Collect profiling information using ruby-prof middleware
```
config.middleware.use Rack::RubyProf, :path => './rubyprof/bullet-on'
```
